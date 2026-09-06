#!/bin/bash
# macOS App Cleaner — interactive uninstaller
# Usage: ./appcleaner.sh

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Hardcoded absolute paths for anything invoked with sudo — avoids PATH hijacking
RM_BIN="/bin/rm"
TCCUTIL_BIN="/usr/bin/tccutil"
LAUNCHCTL_BIN="/bin/launchctl"
PKGUTIL_BIN="/usr/sbin/pkgutil"

#LOG_FILE="$HOME/Library/Logs/appcleaner.log"
LOG_FILE="./Logs/appcleaner.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# ---------- helpers ----------

log_action() {
    printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE" 2>/dev/null
}

human_size() { du -sh -- "$1" 2>/dev/null | cut -f1; }

get_bundle_id() {
    local raw
    raw=$(mdls -name kMDItemCFBundleIdentifier -raw "$1" 2>/dev/null)
    if [ -z "$raw" ] || [ "$raw" = "(null)" ]; then
        echo ""
    else
        echo "$raw"
    fi
}

sql_escape() { printf '%s' "$1" | sed "s/'/''/g"; }

as_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# Least-privilege removal: try unprivileged first, escalate only on actual failure.
# Reports and logs the real outcome instead of assuming success.
remove_path() {
    local path="$1"
    [ -e "$path" ] || return 0
    if "$RM_BIN" -rf -- "$path" 2>/dev/null; then
        log_action "REMOVED (user): $path"; return 0
    fi
    if sudo "$RM_BIN" -rf -- "$path"; then
        log_action "REMOVED (sudo): $path"; return 0
    fi
    log_action "FAILED: $path"
    echo -e "${RED}  Failed to remove: $path${NC}"
    return 1
}

# Exact-match paths only — safe to auto-include in deletion
related_paths() {
    local app_name="$1" bid="$2"
    local paths=()
    if [ -n "$app_name" ]; then
        paths+=(
            "$HOME/Library/Application Support/$app_name"
            "$HOME/Library/Caches/$app_name"
            "$HOME/Library/Logs/$app_name"
            "/Library/Application Support/$app_name"
        )
    fi
    if [ -n "$bid" ]; then
        paths+=(
            "$HOME/Library/Caches/$bid"
            "$HOME/Library/Preferences/$bid.plist"
            "$HOME/Library/Saved Application State/${bid}.savedState"
            "$HOME/Library/Containers/$bid"
            "$HOME/Library/HTTPStorages/$bid"
            "$HOME/Library/WebKit/$bid"
            "$HOME/Library/LaunchAgents/$bid.plist"
            "/Library/LaunchAgents/$bid.plist"
            "/Library/LaunchDaemons/$bid.plist"
        )
    fi
    for p in "${paths[@]}"; do [ -e "$p" ] && echo "$p"; done
}

# Glob match (Group Containers use a TEAMID prefix) — shown and confirmed separately,
# never silently folded into the exact-match deletion list
fuzzy_group_containers() {
    local bid="$1"
    [ -z "$bid" ] && return
    local gc
    for gc in "$HOME/Library/Group Containers/"*"$bid"; do
        [ -e "$gc" ] && echo "$gc"
    done
}

receipts_for() {
    local bid="$1"
    [ -z "$bid" ] && return
    "$PKGUTIL_BIN" --pkgs 2>/dev/null | grep -i -- "$bid"
}

tcc_permissions_for() {
    local bid="$1"
    [ -z "$bid" ] && return
    local bid_escaped; bid_escaped=$(sql_escape "$bid")
    for db in "$HOME/Library/Application Support/com.apple.TCC/TCC.db" "/Library/Application Support/com.apple.TCC/TCC.db"; do
        [ -f "$db" ] || continue
        sqlite3 "$db" "SELECT service, client FROM access WHERE client LIKE '%${bid_escaped}%';" 2>/dev/null
    done
}

confirm() {
    local prompt="$1"
    read -rp "$(echo -e "${YELLOW}${prompt} [y/N]: ${NC}")" ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

is_app_running() {
    pgrep -f "${1}[.]app/Contents/MacOS/" >/dev/null 2>&1
}

ensure_app_quit() {
    local app_name="$1"
    [ -z "$app_name" ] && return 0
    is_app_running "$app_name" || return 0

    echo -e "${YELLOW}$app_name appears to be running.${NC}"
    if confirm "Quit it now before continuing?"; then
        local safe_name; safe_name=$(as_escape "$app_name")
        osascript -e "tell application \"$safe_name\" to quit" 2>/dev/null
        sleep 1
        if is_app_running "$app_name"; then
            echo "Still running — force quitting."
            pkill -f "${app_name}[.]app/Contents/MacOS/" 2>/dev/null
            sleep 1
        fi
    fi

    if is_app_running "$app_name"; then
        confirm "$app_name is still running. Continue anyway?" || return 1
    fi
    return 0
}

# ---------- steps ----------

list_apps() {
    echo -e "${BLUE}Installed applications:${NC}"
    local i=1
    apps=()
    while IFS= read -r -d '' app; do
        apps+=("$app")
        printf "%3d) %s\n" "$i" "$(basename "$app" .app)"
        ((i++))
    done < <(find /Applications -maxdepth 1 -iname "*.app" -print0 | sort -z)
}

dry_run() {
    local app_path="$1" app_name="$2" bid="$3"

    echo -e "\n${BLUE}== Dry run: $app_name ${bid:+($bid)} ==${NC}"
    [ -z "$bid" ] && echo -e "${YELLOW}  Could not resolve a bundle ID — Caches/Containers/receipts/TCC lookups will be skipped.${NC}"
    if [ -n "$app_path" ]; then
        echo -e "${GREEN}App bundle:${NC} $app_path  [$(human_size "$app_path")]"
    else
        echo -e "${YELLOW}App bundle:${NC} not currently installed — leftover-only mode."
    fi

    echo -e "\n${GREEN}Related files/folders found:${NC}"
    local found_paths=()
    while IFS= read -r p; do found_paths+=("$p"); done < <(related_paths "$app_name" "$bid")
    if [ ${#found_paths[@]} -eq 0 ]; then
        echo "  (none found via known patterns)"
    else
        for p in "${found_paths[@]}"; do printf "  %-70s %s\n" "$p" "[$(human_size "$p")]"; done
    fi

    local fuzzy_paths=()
    while IFS= read -r p; do fuzzy_paths+=("$p"); done < <(fuzzy_group_containers "$bid")
    if [ ${#fuzzy_paths[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Fuzzy matches (Group Containers, suffix-matched — verify before deleting):${NC}"
        for p in "${fuzzy_paths[@]}"; do printf "  %-70s %s\n" "$p" "[$(human_size "$p")]"; done
    fi

    echo -e "\n${GREEN}Broader search (mdfind, informational only — never auto-deleted):${NC}"
    if [ -n "$app_name" ]; then
        mdfind -name "$app_name" -onlyin "$HOME/Library" 2>/dev/null | grep -F -v -- "$app_path" | while read -r extra; do
            echo "  $extra  [$(human_size "$extra")]"
        done
    fi

    echo -e "\n${GREEN}Receipts:${NC}"
    receipts_for "$bid" | while read -r r; do echo "  $r"; done

    echo -e "\n${GREEN}TCC / privacy permissions (needs Full Disk Access for this terminal to read):${NC}"
    tcc_permissions_for "$bid" | while read -r line; do echo "  $line"; done
    echo ""
}

do_normal_clean() {
    local app_path="$1" app_name="$2"
    ensure_app_quit "$app_name" || { echo "Cancelled."; return; }
    echo -e "${YELLOW}This will remove the app bundle only:${NC}\n  $app_path"
    confirm "Proceed with normal clean?" || { echo "Cancelled."; return; }
    remove_path "$app_path" && echo -e "${GREEN}Done.${NC}"
}

do_advanced_clean() {
    local app_path="$1" app_name="$2" bid="$3"
    if [ -n "$app_name" ]; then
        ensure_app_quit "$app_name" || { echo "Cancelled."; return; }
    fi

    local found_paths=()
    while IFS= read -r p; do found_paths+=("$p"); done < <(related_paths "$app_name" "$bid")
    local fuzzy_paths=()
    while IFS= read -r p; do fuzzy_paths+=("$p"); done < <(fuzzy_group_containers "$bid")

    echo -e "${YELLOW}This will remove the app bundle plus:${NC}"
    if [ ${#found_paths[@]} -gt 0 ]; then
        for p in "${found_paths[@]}"; do echo "  $p"; done
    else
        echo "  (no related files matched)"
    fi
    confirm "Proceed with advanced clean?" || { echo "Cancelled."; return; }

    local failures=0 la
    for la in "$HOME/Library/LaunchAgents/$bid.plist" "/Library/LaunchAgents/$bid.plist" "/Library/LaunchDaemons/$bid.plist"; do
        [ -n "$bid" ] && [ -f "$la" ] || continue
        "$LAUNCHCTL_BIN" unload "$la" 2>/dev/null || sudo "$LAUNCHCTL_BIN" unload "$la" 2>/dev/null
    done

    if [ -n "$app_path" ]; then
        remove_path "$app_path" || ((failures++))
    fi
    if [ ${#found_paths[@]} -gt 0 ]; then
        for p in "${found_paths[@]}"; do remove_path "$p" || ((failures++)); done
    fi

    if [ ${#fuzzy_paths[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Fuzzy-matched Group Containers (verify these belong to $app_name):${NC}"
        for p in "${fuzzy_paths[@]}"; do echo "  $p"; done
        if confirm "Also remove these?"; then
            for p in "${fuzzy_paths[@]}"; do remove_path "$p" || ((failures++)); done
        fi
    fi

    killall cfprefsd 2>/dev/null

    if [ "$failures" -eq 0 ]; then
        echo -e "${GREEN}Advanced clean done — see $LOG_FILE for details.${NC}"
    else
        echo -e "${RED}Advanced clean finished with $failures failure(s) — see $LOG_FILE.${NC}"
    fi
}

do_complete_clean() {
    local app_path="$1" app_name="$2" bid="$3"

    echo -e "${RED}=========================================================${NC}"
    echo -e "${RED} COMPLETE CLEANUP — this also removes install receipts${NC}"
    echo -e "${RED} and resets TCC (privacy) permission grants for this app.${NC}"
    echo -e "${RED} This cannot be undone. Reinstalling will require you to${NC}"
    echo -e "${RED} re-grant camera/mic/disk/etc. access if you use it again.${NC}"
    echo -e "${RED}=========================================================${NC}"
    confirm "Continue to complete cleanup?" || { echo "Cancelled."; return; }

    do_advanced_clean "$app_path" "$app_name" "$bid"

    if [ -z "$bid" ]; then
        echo -e "${YELLOW}No bundle ID resolved — skipping receipts and TCC lookup.${NC}"
        return
    fi

    echo -e "\n${GREEN}Receipts found:${NC}"
    local receipts=()
    while IFS= read -r r; do receipts+=("$r"); done < <(receipts_for "$bid")
    if [ ${#receipts[@]} -gt 0 ]; then
        for r in "${receipts[@]}"; do echo "  $r"; done
    else
        echo "  (none found)"
    fi
    if [ ${#receipts[@]} -gt 0 ] && confirm "Forget these receipts?"; then
        for r in "${receipts[@]}"; do
            "$PKGUTIL_BIN" --forget "$r" 2>/dev/null || sudo "$PKGUTIL_BIN" --forget "$r" 2>/dev/null
            log_action "FORGOT RECEIPT: $r"
        done
        echo -e "${GREEN}Receipts forgotten.${NC}"
    fi

    echo -e "\n${GREEN}TCC permissions found:${NC}"
    perms=$(tcc_permissions_for "$bid")
    if [ -n "$perms" ]; then
        echo "$perms" | sed 's/^/  /'
        if confirm "Reset all privacy permissions for $bid?"; then
            "$TCCUTIL_BIN" reset All "$bid" 2>/dev/null || sudo "$TCCUTIL_BIN" reset All "$bid" 2>/dev/null
            log_action "TCC RESET: $bid"
            echo -e "${GREEN}Permissions reset.${NC}"
        fi
    else
        echo "  (none found — or this terminal lacks Full Disk Access to read TCC.db)"
    fi

    echo -e "${GREEN}Complete cleanup finished — see $LOG_FILE for a full record.${NC}"
}

# ---------- main menu ----------

find_installed_app_by_bid() {
    local bid="$1" hits preferred
    hits=$(mdfind "kMDItemCFBundleIdentifier == '$bid'" 2>/dev/null | grep '\.app$')
    [ -z "$hits" ] && return 1
    preferred=$(echo "$hits" | grep '^/Applications/' | head -n1)
    if [ -n "$preferred" ]; then echo "$preferred"; else echo "$hits" | head -n1; fi
}

run_flow() {
    local app_path="$1" app_name="$2" bid="$3"
    dry_run "$app_path" "$app_name" "$bid"

    echo -e "${BLUE}Choose an action:${NC}"
    [ -n "$app_path" ] && echo "  1) Normal clean   (remove app bundle only)"
    if [ -n "$app_path" ]; then
        echo "  2) Advanced clean (bundle + support/cache/prefs/containers/launch agents)"
    else
        echo "  2) Advanced clean (support/cache/prefs/containers/launch agents)"
    fi
    echo "  3) Complete clean (advanced + receipts + TCC permissions, with prompts)"
    echo "  4) Cancel"
    read -rp "$(echo -e "${BLUE}Choice: ${NC}")" choice

    case "$choice" in
        1) if [ -n "$app_path" ]; then do_normal_clean "$app_path" "$app_name"; else echo "No app bundle to remove."; fi ;;
        2) do_advanced_clean "$app_path" "$app_name" "$bid" ;;
        3) do_complete_clean "$app_path" "$app_name" "$bid" ;;
        *) echo "Cancelled." ;;
    esac
}

select_from_list() {
    list_apps
    read -rp "$(echo -e "${BLUE}Select app number: ${NC}")" idx

    if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#apps[@]}" ]; then
        echo "Invalid selection."; exit 1
    fi

    local app_path="${apps[$((idx-1))]}"
    local app_name; app_name=$(basename "$app_path" .app)
    local bid; bid=$(get_bundle_id "$app_path")

    run_flow "$app_path" "$app_name" "$bid"
}

select_by_bundle_id() {
    local bid app_path app_name
    read -rp "$(echo -e "${BLUE}Bundle ID (e.g. com.company.appname): ${NC}")" bid

    if ! [[ "$bid" =~ ^[A-Za-z0-9._-]+$ ]]; then
        echo "Invalid bundle ID format."; exit 1
    fi

    echo "Searching for an installed app with this bundle ID..."
    app_path=$(find_installed_app_by_bid "$bid")

    if [ -n "$app_path" ]; then
        app_name=$(basename "$app_path" .app)
        echo -e "${GREEN}Found installed app:${NC} $app_path"
    else
        echo -e "${YELLOW}No installed app found — leftover-only mode.${NC}"
        read -rp "Optional app display name, to also match name-based folders like 'Application Support/AppName' (blank to skip): " app_name
        app_path=""
    fi

    run_flow "$app_path" "$app_name" "$bid"
}

main() {
    echo -e "${BLUE}How would you like to find the app?${NC}"
    echo "  1) Choose from installed apps in /Applications"
    echo "  2) Enter a bundle ID (also works for apps already removed)"
    read -rp "$(echo -e "${BLUE}Choice: ${NC}")" mode

    case "$mode" in
        2) select_by_bundle_id ;;
        *) select_from_list ;;
    esac
}

main