#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  dev-clean.sh — Interactive Dev Tools Manager
#  Usage:  chmod +x dev-clean.sh && ./dev-clean.sh
# ─────────────────────────────────────────────────────────────────────────────

RED=$'\e[0;31m'; GRN=$'\e[0;32m'; YLW=$'\e[0;33m'
BLU=$'\e[0;34m'; CYN=$'\e[0;36m'; DIM=$'\e[2m'; BOLD=$'\e[1m'; RST=$'\e[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
has()   { command -v "$1" &>/dev/null; }
ok()    { printf "  ${GRN}✓${RST} %s\n" "$*"; }
warn()  { printf "  ${YLW}⚠${RST}  %s\n" "$*"; }
fail()  { printf "  ${RED}✗${RST} %s\n" "$*"; }
dim()   { printf "  ${DIM}%s${RST}\n" "$*"; }
sep()   { printf "  ${DIM}──────────────────────────────────────────────${RST}\n"; }
sec()   { printf "\n${BOLD}${YLW}  ▸ %s${RST}\n" "$*"; }
row()   { printf "  ${CYN}%-26s${RST}${BOLD}%s${RST}\n" "$1" "$2"; }

header() {
  clear
  printf "${BOLD}${BLU}\n"
  printf "  ╔══════════════════════════════════════════════╗\n"
  printf "  ║  %-44s║\n" "  $*"
  printf "  ╚══════════════════════════════════════════════╝\n"
  printf "${RST}\n"
}

dir_size() { [[ -d "$1" ]] && du -sh "$1" 2>/dev/null | awk '{print $1}' || printf "—"; }

confirm() {
  printf "\n  ${YLW}${BOLD}%s${RST}\n  ${DIM}[y/N]: ${RST}" "$*"
  read -r _r; [[ "$_r" =~ ^[Yy]$ ]]
}

press_enter() { printf "\n  ${DIM}Press Enter to continue…${RST}"; read -r; }

# ── Global Xcode / Sim paths ──────────────────────────────────────────────────
XDD="$HOME/Library/Developer/Xcode/DerivedData"
XARCH="$HOME/Library/Developer/Xcode/Archives"
XDS="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
XC="$HOME/Library/Caches/com.apple.dt.Xcode"
SPM="$HOME/Library/Caches/org.swift.swiftpm"
CS="$HOME/Library/Developer/CoreSimulator"

# ═══════════════════════════════════════════════════════════════════════════════
# BREW
# ═══════════════════════════════════════════════════════════════════════════════
menu_brew() {
  while true; do
    header "🍺  Homebrew"
    if ! has brew; then fail "Homebrew not found"; press_enter; return; fi

    sec "Version"
    brew --version 2>/dev/null | head -1 | sed 's/^/  /'

    sec "Packages"
    local nf nc
    nf=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
    nc=$(brew list --cask    2>/dev/null | wc -l | tr -d ' ')
    printf "  Formulae: ${BOLD}%s${RST}   Casks: ${BOLD}%s${RST}\n" "$nf" "$nc"

    sec "Disk Usage"
    local cache_dir cellar
    cache_dir=$(brew --cache 2>/dev/null)
    cellar="/opt/homebrew/Cellar"
    [[ -d "/usr/local/Cellar" ]] && cellar="/usr/local/Cellar"
    row "Cellar" "$(dir_size "$cellar")"
    row "Cache"  "$(dir_size "$cache_dir")"
    dim "$cache_dir"

    sec "Outdated"
    local outdated; outdated=$(brew outdated 2>/dev/null)
    if [[ -z "$outdated" ]]; then ok "All packages up to date"
    else warn "$(echo "$outdated" | wc -l | tr -d ' ') package(s) outdated:"; echo "$outdated" | sed 's/^/    /'; fi

    sep
    printf "  ${BOLD}[1]${RST}  cleanup --prune=all   ${DIM}(old versions + downloads)${RST}\n"
    printf "  ${BOLD}[2]${RST}  autoremove            ${DIM}(unused dependencies)${RST}\n"
    printf "  ${BOLD}[3]${RST}  Both\n"
    printf "  ${BOLD}[u]${RST}  upgrade all\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) if confirm "Run: brew cleanup --prune=all"; then
           brew cleanup --prune=all; ok "Done"; press_enter; fi ;;
      2) if confirm "Run: brew autoremove"; then
           brew autoremove; ok "Done"; press_enter; fi ;;
      3) if confirm "Run cleanup + autoremove"; then
           brew cleanup --prune=all && brew autoremove; ok "Done"; press_enter; fi ;;
      u|U) if confirm "Run: brew upgrade"; then
             brew upgrade; ok "Done"; press_enter; fi ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODE / NPM
# ═══════════════════════════════════════════════════════════════════════════════
menu_node() {
  while true; do
    header "📦  Node / NPM"

    sec "Versions"
    has node && ok "node  $(node -v)"          || fail "node not installed"
    has npm  && ok "npm   v$(npm -v)"         || fail "npm not installed"
    has yarn && ok "yarn  $(yarn -v)"
    has pnpm && ok "pnpm  $(pnpm -v)"
    has bun  && ok "bun   $(bun --version 2>/dev/null)"

    sec "Disk Usage"
    if has npm; then
      local npm_cache npm_global
      npm_cache=$(npm config get cache 2>/dev/null)
      npm_global=$(npm root -g 2>/dev/null)
      row "npm cache"   "$(dir_size "$npm_cache")"
      row "npm globals" "$(dir_size "$npm_global")"
    fi
    if has yarn; then
      local yarn_cache; yarn_cache=$(yarn cache dir 2>/dev/null)
      row "yarn cache" "$(dir_size "$yarn_cache")"
    fi
    if has pnpm; then
      local pnpm_store; pnpm_store=$(pnpm store path 2>/dev/null)
      row "pnpm store" "$(dir_size "$pnpm_store")"
    fi

    sep
    printf "  ${BOLD}[1]${RST}  npm cache clean --force\n"
    printf "  ${BOLD}[2]${RST}  yarn cache clean\n"
    printf "  ${BOLD}[3]${RST}  pnpm store prune\n"
    printf "  ${BOLD}[4]${RST}  List global npm packages\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) if ! has npm;  then fail "npm not found";  press_enter; continue; fi
         if confirm "Run: npm cache clean --force"; then
           npm cache clean --force; ok "Done"; press_enter; fi ;;
      2) if ! has yarn; then fail "yarn not found"; press_enter; continue; fi
         if confirm "Run: yarn cache clean"; then
           yarn cache clean; ok "Done"; press_enter; fi ;;
      3) if ! has pnpm; then fail "pnpm not found"; press_enter; continue; fi
         if confirm "Run: pnpm store prune"; then
           pnpm store prune; ok "Done"; press_enter; fi ;;
      4) sec "Global npm packages"
         npm list -g --depth=0 2>/dev/null | tail -n +2 | sed 's/^/    /'
         press_enter ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# PIP3
# ═══════════════════════════════════════════════════════════════════════════════
menu_pip() {
  while true; do
    header "🐍  pip3"
    if ! has pip3; then fail "pip3 not found"; press_enter; return; fi

    sec "Version"
    pip3 --version 2>/dev/null | sed 's/^/  /'

    sec "Disk Usage"
    local pd; pd=$(pip3 cache dir 2>/dev/null)
    row "Cache" "$(dir_size "$pd")"
    dim "$pd"

    sec "Installed"
    local n; n=$(pip3 list 2>/dev/null | tail -n +3 | wc -l | tr -d ' ')
    printf "  ${BOLD}%s${RST} packages installed\n" "$n"

    sep
    printf "  ${BOLD}[1]${RST}  pip3 cache purge\n"
    printf "  ${BOLD}[2]${RST}  Show outdated packages\n"
    printf "  ${BOLD}[3]${RST}  List all installed\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) if confirm "Run: pip3 cache purge"; then
           pip3 cache purge; ok "Done"; press_enter; fi ;;
      2) sec "Outdated"; pip3 list --outdated 2>/dev/null | sed 's/^/    /'; press_enter ;;
      3) sec "All packages"; pip3 list 2>/dev/null | sed 's/^/    /'; press_enter ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# RUSTUP / CARGO
# ═══════════════════════════════════════════════════════════════════════════════
menu_rust() {
  while true; do
    header "🦀  Rust / Rustup"
    if ! has rustup; then fail "rustup not found"; press_enter; return; fi

    sec "Versions"
    has rustc && ok "rustc  $(rustc --version 2>/dev/null)"
    has cargo && ok "cargo  $(cargo --version 2>/dev/null)"
    ok "rustup $(rustup --version 2>/dev/null | awk '{print $2}')"

    sec "Toolchains"
    rustup toolchain list 2>/dev/null | sed 's/^/    /'

    sec "Installed Targets"
    rustup target list --installed 2>/dev/null | sed 's/^/    /'

    sec "Disk Usage"
    row "~/.rustup"         "$(dir_size "$HOME/.rustup")"
    row "~/.cargo"          "$(dir_size "$HOME/.cargo")"
    row "  registry/cache"  "$(dir_size "$HOME/.cargo/registry/cache")"
    row "  git"             "$(dir_size "$HOME/.cargo/git")"

    sep
    printf "  ${BOLD}[1]${RST}  Uninstall a toolchain\n"
    printf "  ${BOLD}[2]${RST}  Clean cargo registry cache   ${DIM}(~/.cargo/registry/cache)${RST}\n"
    printf "  ${BOLD}[3]${RST}  Clean cargo git cache        ${DIM}(~/.cargo/git)${RST}\n"
    printf "  ${BOLD}[4]${RST}  Clean all cargo cache\n"
    printf "  ${BOLD}[5]${RST}  rustup update\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) printf "\n  Toolchain to uninstall (empty = cancel): "; read -r tc
         if [[ -n "$tc" ]] && confirm "Uninstall '$tc'?"; then
           rustup toolchain uninstall "$tc"; ok "Done"; press_enter; fi ;;
      2) if confirm "Remove ~/.cargo/registry/cache?"; then
           rm -rf "$HOME/.cargo/registry/cache"; ok "Done"; press_enter; fi ;;
      3) if confirm "Remove ~/.cargo/git?"; then
           rm -rf "$HOME/.cargo/git"; ok "Done"; press_enter; fi ;;
      4) if confirm "Remove all cargo cache (registry + git)?"; then
           rm -rf "$HOME/.cargo/registry/cache" "$HOME/.cargo/git"
           ok "Done"; press_enter; fi ;;
      5) rustup update; press_enter ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# ANDROID SDK
# ═══════════════════════════════════════════════════════════════════════════════
menu_android() {
  local SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  while true; do
    header "🤖  Android SDK"

    sec "SDK Location"
    if [[ ! -d "$SDK" ]]; then
      fail "Not found at $SDK"
      dim "Set ANDROID_HOME if your SDK is elsewhere"; press_enter; return
    fi
    ok "$SDK"

    sec "Disk Usage"
    row "SDK root"        "$(dir_size "$SDK")"
    row "  build-tools"   "$(dir_size "$SDK/build-tools")"
    row "  platforms"     "$(dir_size "$SDK/platforms")"
    row "  system-images" "$(dir_size "$SDK/system-images")"
    row "  emulator"      "$(dir_size "$SDK/emulator")"
    row "~/.android"      "$(dir_size "$HOME/.android")"
    row "  avd"           "$(dir_size "$HOME/.android/avd")"

    sec "Installed Platforms"
    ls "$SDK/platforms" 2>/dev/null | sed 's/^/    /' || dim "none"

    sec "Build Tools Versions"
    ls "$SDK/build-tools" 2>/dev/null | sed 's/^/    /' || dim "none"

    sec "AVDs"
    ls "$HOME/.android/avd" 2>/dev/null | grep '\.avd$' | sed 's/\.avd$//' | sed 's/^/    /' || dim "none"

    sep
    printf "  ${BOLD}[1]${RST}  Remove a build-tools version\n"
    printf "  ${BOLD}[2]${RST}  Clean ~/.android/cache\n"
    printf "  ${BOLD}[3]${RST}  System images info           ${DIM}(use SDK Manager to remove)${RST}\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) printf "\n  Build-tools version to remove (e.g. 34.0.0, empty = cancel): "; read -r v
         if [[ -z "$v" ]]; then continue; fi
         if [[ -d "$SDK/build-tools/$v" ]]; then
           if confirm "Remove build-tools $v?"; then rm -rf "$SDK/build-tools/$v"; ok "Done"; press_enter; fi
         else warn "Version '$v' not found"; press_enter; fi ;;
      2) if confirm "Delete ~/.android/cache?"; then
           rm -rf "$HOME/.android/cache"; ok "Done"; press_enter; fi ;;
      3) sec "System images (use Android Studio → SDK Manager to remove):"
         ls "$SDK/system-images" 2>/dev/null | sed 's/^/    /' || dim "none"
         press_enter ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# GRADLE
# ═══════════════════════════════════════════════════════════════════════════════
menu_gradle() {
  while true; do
    header "🐘  Gradle"

    sec "Version"
    if has gradle; then
      gradle --version 2>/dev/null | grep "^Gradle" | sed 's/^/  /'
    else
      dim "gradle CLI not in PATH — wrapper (./gradlew) usage is normal"
    fi

    sec "Disk Usage"
    row "~/.gradle"       "$(dir_size "$HOME/.gradle")"
    row "  ├─ caches"     "$(dir_size "$HOME/.gradle/caches")"
    row "  ├─ daemon"     "$(dir_size "$HOME/.gradle/daemon")"
    row "  └─ wrapper"    "$(dir_size "$HOME/.gradle/wrapper")"

    sec "Daemon Status"
    if has gradle; then
      gradle --status 2>/dev/null | grep -v "^$" | head -8 | sed 's/^/    /' \
        || dim "No running daemons"
    else
      dim "Run ./gradlew --status inside a project"
    fi

    sep
    printf "  ${BOLD}[1]${RST}  Clean caches   ${DIM}(rm -rf ~/.gradle/caches)${RST}\n"
    printf "  ${BOLD}[2]${RST}  Clean daemon   ${DIM}(rm -rf ~/.gradle/daemon)${RST}\n"
    printf "  ${BOLD}[3]${RST}  Clean wrappers ${DIM}(rm -rf ~/.gradle/wrapper)${RST}\n"
    printf "  ${BOLD}[4]${RST}  Clean all three\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) if confirm "Delete ~/.gradle/caches?"; then
           rm -rf "$HOME/.gradle/caches";  ok "Done"; press_enter; fi ;;
      2) if confirm "Delete ~/.gradle/daemon?"; then
           rm -rf "$HOME/.gradle/daemon";  ok "Done"; press_enter; fi ;;
      3) if confirm "Delete ~/.gradle/wrapper?"; then
           rm -rf "$HOME/.gradle/wrapper"; ok "Done"; press_enter; fi ;;
      4) if confirm "Delete caches + daemon + wrapper?"; then
           rm -rf "$HOME/.gradle/caches" "$HOME/.gradle/daemon" "$HOME/.gradle/wrapper"
           ok "Done"; press_enter; fi ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# XCODE
# ═══════════════════════════════════════════════════════════════════════════════
menu_xcode() {
  while true; do
    header "🔨  Xcode"
    if ! has xcodebuild; then fail "Xcode not installed"; press_enter; return; fi

    sec "Version"
    xcodebuild -version 2>/dev/null | sed 's/^/  /'

    sec "Disk Usage"
    row "DerivedData"        "$(dir_size "$XDD")"
    row "Archives"           "$(dir_size "$XARCH")"
    row "iOS Device Support" "$(dir_size "$XDS")"
    row "Xcode Cache"        "$(dir_size "$XC")"
    row "SPM Cache"          "$(dir_size "$SPM")"

    sec "DerivedData — Top 10 by Size"
    if [[ -d "$XDD" ]]; then
      du -sh "$XDD"/*/ 2>/dev/null | sort -rh | head -10 | \
        awk -v b="$XDD/" '{gsub(b,"",$2); gsub("/","",$2); printf "    %-10s %s\n",$1,$2}'
    else dim "DerivedData not found"; fi

    sep
    printf "  ${BOLD}[1]${RST}  Delete DerivedData\n"
    printf "  ${BOLD}[2]${RST}  Delete Xcode cache\n"
    printf "  ${BOLD}[3]${RST}  Delete iOS Device Support    ${DIM}(re-downloads on device connect)${RST}\n"
    printf "  ${BOLD}[4]${RST}  Delete SPM cache\n"
    printf "  ${BOLD}[5]${RST}  Delete Archives              ${RED}(⚠  .ipa + .dSYM files!)${RST}\n"
    printf "  ${BOLD}[6]${RST}  Clean all except Archives\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) if confirm "Delete DerivedData?"; then
           rm -rf "$XDD";   ok "Done"; press_enter; fi ;;
      2) if confirm "Delete Xcode cache?"; then
           rm -rf "$XC";    ok "Done"; press_enter; fi ;;
      3) if confirm "Delete iOS Device Support?"; then
           rm -rf "$XDS";   ok "Done"; press_enter; fi ;;
      4) if confirm "Delete SPM cache?"; then
           rm -rf "$SPM";   ok "Done"; press_enter; fi ;;
      5) warn "Archives contain your signed .ipa and crash symbol (.dSYM) files."
         if confirm "⚠  Permanently delete ALL Archives?"; then
           rm -rf "$XARCH"; ok "Done"; press_enter; fi ;;
      6) if confirm "Delete DerivedData + Cache + Device Support + SPM (keep Archives)?"; then
           rm -rf "$XDD" "$XC" "$XDS" "$SPM"; ok "Done"; press_enter; fi ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# SIMULATOR
# ═══════════════════════════════════════════════════════════════════════════════
menu_sim() {
  while true; do
    header "📱  iOS Simulator"
    if ! has xcrun; then fail "Xcode CLT not found"; press_enter; return; fi

    sec "Disk Usage"
    row "CoreSimulator" "$(dir_size "$CS")"
    row "  Devices"     "$(dir_size "$CS/Devices")"
    row "  Caches"      "$(dir_size "$CS/Caches")"

    sec "Runtimes"
    xcrun simctl list runtimes 2>/dev/null | grep -v "^==" | grep -v "^$" | sed 's/^/    /'

    sec "Booted Simulators"
    local booted; booted=$(xcrun simctl list devices 2>/dev/null | grep "Booted")
    [[ -n "$booted" ]] && echo "$booted" | sed 's/^/    /' || dim "None booted"

    sec "Counts"
    local total unavail
    total=$(xcrun simctl list devices 2>/dev/null | grep -E "\(Booted\)|\(Shutdown\)" | wc -l | tr -d ' ')
    unavail=$(xcrun simctl list devices 2>/dev/null | grep "unavailable" | wc -l | tr -d ' ')
    printf "  Total: ${BOLD}%s${RST}   Unavailable: ${BOLD}%s${RST}\n" "$total" "$unavail"

    sep
    printf "  ${BOLD}[1]${RST}  Delete unavailable simulators  ${DIM}(simctl delete unavailable)${RST}\n"
    printf "  ${BOLD}[2]${RST}  Delete CoreSimulator caches\n"
    printf "  ${BOLD}[3]${RST}  Shutdown all simulators\n"
    printf "  ${BOLD}[4]${RST}  List all devices\n"
    printf "  ${BOLD}[5]${RST}  Erase all simulator content    ${RED}(⚠  wipes all app data!)${RST}\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) if confirm "Delete unavailable simulators?"; then
           xcrun simctl delete unavailable; ok "Done"; press_enter; fi ;;
      2) if confirm "Delete CoreSimulator/Caches?"; then
           rm -rf "$CS/Caches"; ok "Done"; press_enter; fi ;;
      3) if confirm "Shutdown all simulators?"; then
           xcrun simctl shutdown all; ok "Done"; press_enter; fi ;;
      4) xcrun simctl list devices | grep -v "^==" | sed 's/^/    /'; press_enter ;;
      5) warn "This wipes installed apps and data across EVERY simulator."
         if confirm "⚠  Erase ALL simulator content?"; then
           xcrun simctl erase all; ok "Done"; press_enter; fi ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# DOCKER
# ═══════════════════════════════════════════════════════════════════════════════
menu_docker() {
  while true; do
    header "🐳  Docker"
    if ! has docker; then fail "Docker not found"; press_enter; return; fi

    # Verify daemon is reachable
    if ! docker info &>/dev/null; then
      fail "Docker daemon not running — start Docker Desktop first"
      press_enter; return
    fi

    sec "Version"
    docker --version 2>/dev/null | sed 's/^/  /'
    docker compose version 2>/dev/null | sed 's/^/  /' || true

    sec "Disk Usage"
    docker system df 2>/dev/null | sed 's/^/  /'

    sec "Resources"
    local imgs conts vols
    imgs=$(docker images  -q   2>/dev/null | wc -l | tr -d ' ')
    conts=$(docker ps    -aq   2>/dev/null | wc -l | tr -d ' ')
    vols=$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')
    row "Images"            "$imgs"
    row "Containers (all)"  "$conts"
    row "Volumes"           "$vols"

    sec "Running Containers"
    local running
    running=$(docker ps --format "{{.Names}}  {{.Status}}  {{.Image}}" 2>/dev/null)
    [[ -n "$running" ]] && echo "$running" | sed 's/^/    /' || dim "None running"

    sep
    printf "  ${BOLD}[1]${RST}  system prune          ${DIM}(stopped containers, dangling images, unused networks)${RST}\n"
    printf "  ${BOLD}[2]${RST}  system prune -a       ${DIM}(+ ALL unused images — not just dangling)${RST}\n"
    printf "  ${BOLD}[3]${RST}  image prune           ${DIM}(dangling images only)${RST}\n"
    printf "  ${BOLD}[4]${RST}  image prune -a        ${DIM}(all unused images)${RST}\n"
    printf "  ${BOLD}[5]${RST}  container prune       ${DIM}(stopped containers)${RST}\n"
    printf "  ${BOLD}[6]${RST}  volume prune          ${RED}(⚠  db data and uploads may be lost!)${RST}\n"
    printf "  ${BOLD}[7]${RST}  builder prune         ${DIM}(dangling build cache layers)${RST}\n"
    printf "  ${BOLD}[8]${RST}  builder prune -a      ${DIM}(all build cache)${RST}\n"
    printf "  ${BOLD}[b]${RST}  ← Back\n\n"
    printf "  Choice: "; read -r ch

    case $ch in
      1) if confirm "Run: docker system prune?"; then
           docker system prune -f; ok "Done"; press_enter; fi ;;
      2) if confirm "Run: docker system prune -a? (removes ALL unused images)"; then
           docker system prune -af; ok "Done"; press_enter; fi ;;
      3) if confirm "Run: docker image prune?"; then
           docker image prune -f; ok "Done"; press_enter; fi ;;
      4) if confirm "Run: docker image prune -a?"; then
           docker image prune -af; ok "Done"; press_enter; fi ;;
      5) if confirm "Run: docker container prune?"; then
           docker container prune -f; ok "Done"; press_enter; fi ;;
      6) warn "Volumes may contain database data, uploads, or other persistent state."
         warn "Containers using a volume must be stopped first or the volume is skipped."
         if confirm "⚠  Run: docker volume prune?"; then
           docker volume prune -f; ok "Done"; press_enter; fi ;;
      7) if confirm "Run: docker builder prune?"; then
           docker builder prune -f; ok "Done"; press_enter; fi ;;
      8) if confirm "Run: docker builder prune -a? (removes ALL build cache)"; then
           docker builder prune -af; ok "Done"; press_enter; fi ;;
      b|B) return ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
_check_tool() {
  local label="$1" cmd="$2" ver=""
  if has "$cmd"; then
    case $cmd in
      brew)       ver=$(brew --version 2>/dev/null | head -1 | awk '{print $2}') ;;
      node)       ver=$(node -v 2>/dev/null) ;;
      npm)        ver="v$(npm -v 2>/dev/null)" ;;
      pip3)       ver=$(pip3 --version 2>/dev/null | awk '{print $2}') ;;
      rustup)     ver=$(rustup --version 2>/dev/null | awk '{print $2}') ;;
      rustc)      ver=$(rustc --version 2>/dev/null | awk '{print $2}') ;;
      gradle)     ver=$(gradle --version 2>/dev/null | grep "^Gradle" | awk '{print $2}') ;;
      xcodebuild) ver=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}') ;;
      xcrun)      ver="CLT installed" ;;
      docker)     ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',') ;;
    esac
    printf "  ${GRN}✓${RST} %-24s ${DIM}%s${RST}\n" "$label" "$ver"
  else
    printf "  ${RED}✗${RST} %-24s ${DIM}not found${RST}\n" "$label"
  fi
}

summary() {
  header "📊  Dev Tools — Usage Summary"

  printf "  ${BOLD}${CYN}%-26s Status / Version${RST}\n" "Tool"
  sep
  _check_tool "Homebrew"            brew
  _check_tool "Node.js"             node
  _check_tool "npm"                 npm
  _check_tool "pip3"                pip3
  _check_tool "rustup"              rustup
  _check_tool "rustc / cargo"       rustc
  _check_tool "Gradle"              gradle
  _check_tool "Xcode"               xcodebuild
  _check_tool "Simulator (xcrun)"   xcrun
  _check_tool "Docker"              docker

  printf "\n  ${BOLD}${CYN}Disk Usage${RST}\n"
  sep

  local brew_cache="—" brew_cellar="—" npm_cache="—" pip_cache="—"
  if has brew; then
    brew_cache=$(dir_size "$(brew --cache 2>/dev/null)")
    [[ -d /opt/homebrew/Cellar ]] && brew_cellar=$(dir_size /opt/homebrew/Cellar)
    [[ -d /usr/local/Cellar    ]] && brew_cellar=$(dir_size /usr/local/Cellar)
  fi
  has npm  && npm_cache=$(dir_size "$(npm config get cache 2>/dev/null)")
  has pip3 && pip_cache=$(dir_size "$(pip3 cache dir 2>/dev/null)")

  row "🍺  Brew Cellar"          "$brew_cellar"
  row "    Brew Cache"           "$brew_cache"
  row "📦  npm cache"            "$npm_cache"
  row "🐍  pip3 cache"           "$pip_cache"
  row "🦀  ~/.rustup"            "$(dir_size "$HOME/.rustup")"
  row "    ~/.cargo"             "$(dir_size "$HOME/.cargo")"
  row "🤖  Android SDK"          "$(dir_size "${ANDROID_HOME:-$HOME/Library/Android/sdk}")"
  row "    ~/.android"           "$(dir_size "$HOME/.android")"
  row "🐘  ~/.gradle"            "$(dir_size "$HOME/.gradle")"
  row "    ├─ caches"            "$(dir_size "$HOME/.gradle/caches")"
  row "    ├─ daemon"            "$(dir_size "$HOME/.gradle/daemon")"
  row "    └─ wrapper"           "$(dir_size "$HOME/.gradle/wrapper")"
  row "🔨  DerivedData"          "$(dir_size "$XDD")"
  row "    Archives"             "$(dir_size "$XARCH")"
  row "    iOS Device Support"   "$(dir_size "$XDS")"
  row "    Xcode Cache"          "$(dir_size "$XC")"
  row "    SPM Cache"            "$(dir_size "$SPM")"
  row "📱  CoreSimulator"        "$(dir_size "$CS")"
  row "    Devices"              "$(dir_size "$CS/Devices")"

  if has docker && docker info &>/dev/null 2>&1; then
    local df_out img_size cont_size vol_size cache_size
    df_out=$(docker system df 2>/dev/null)
    img_size=$(echo   "$df_out" | awk '/^Images/     {print $4}')
    cont_size=$(echo  "$df_out" | awk '/^Containers/ {print $4}')
    vol_size=$(echo   "$df_out" | awk '/Volumes/     {print $5}')
    cache_size=$(echo "$df_out" | awk '/Cache/       {print $5}')
    printf "\n"
    row "🐳  Docker Images"       "${img_size:-—}"
    row "    Containers"          "${cont_size:-—}"
    row "    Local Volumes"       "${vol_size:-—}"
    row "    Build Cache"         "${cache_size:-—}"
  elif has docker; then
    printf "\n"
    row "🐳  Docker"  "${DIM}daemon not running${RST}"
  fi

  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLEAN ALL
# ═══════════════════════════════════════════════════════════════════════════════
clean_all() {
  header "🧹  Clean All Dev Tools"

  printf "  The following will be cleaned:\n\n"
  printf "  ${GRN}•${RST} brew cleanup --prune=all\n"
  printf "  ${GRN}•${RST} npm cache clean --force\n"
  printf "  ${GRN}•${RST} pip3 cache purge\n"
  printf "  ${GRN}•${RST} ~/.cargo/registry/cache + ~/.cargo/git\n"
  printf "  ${GRN}•${RST} ~/.gradle/caches + daemon + wrapper\n"
  printf "  ${GRN}•${RST} Xcode DerivedData + Cache + Device Support + SPM\n"
  printf "  ${GRN}•${RST} xcrun simctl delete unavailable\n"
  printf "  ${GRN}•${RST} docker system prune  ${DIM}(stopped containers, dangling images, unused networks)${RST}\n"
  printf "  ${GRN}•${RST} docker builder prune ${DIM}(dangling build cache layers)${RST}\n\n"
  warn "Archives, AVDs, Simulator app data, and Docker volumes are NOT touched."

  if ! confirm "Proceed with full cleanup?"; then return; fi
  printf "\n"

  _step() {
    local label="$1"; shift
    printf "  ${BOLD}%-32s${RST}" "$label…"
    if "$@" &>/dev/null; then printf "${GRN}✓ done${RST}\n"
    else printf "${YLW}skipped${RST}\n"; fi
  }

  has brew       && _step "Brew"           brew cleanup --prune=all
  has npm        && _step "npm"            npm cache clean --force
  has pip3       && _step "pip3"           pip3 cache purge
  _step "Cargo cache"          rm -rf "$HOME/.cargo/registry/cache" "$HOME/.cargo/git"
  _step "Gradle"               rm -rf "$HOME/.gradle/caches" "$HOME/.gradle/daemon" "$HOME/.gradle/wrapper"
  has xcodebuild && _step "Xcode"          rm -rf "$XDD" "$XC" "$XDS" "$SPM"
  has xcrun      && _step "Simulators"     xcrun simctl delete unavailable
  if has docker && docker info &>/dev/null 2>&1; then
    _step "Docker system"      docker system prune -f
    _step "Docker builder"     docker builder prune -f
  fi

  printf "\n"
  ok "All done! Run [s] Summary to see freed space."
  press_enter
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════════════════════
main() {
  while true; do
    clear
    printf "${BOLD}${BLU}\n"
    printf "  ╔════════════════════════════════════════╗\n"
    printf "  ║        🛠   Dev Tools Manager           ║\n"
    printf "  ╚════════════════════════════════════════╝\n"
    printf "${RST}\n"
    printf "  ${BOLD}[s]${RST}  📊  Usage Summary\n"
    sep
    printf "  ${BOLD}[1]${RST}  🍺  Homebrew\n"
    printf "  ${BOLD}[2]${RST}  📦  Node / NPM\n"
    printf "  ${BOLD}[3]${RST}  🐍  pip3\n"
    printf "  ${BOLD}[4]${RST}  🦀  Rustup / Cargo\n"
    printf "  ${BOLD}[5]${RST}  🤖  Android SDK\n"
    printf "  ${BOLD}[6]${RST}  🐘  Gradle\n"
    printf "  ${BOLD}[7]${RST}  🔨  Xcode\n"
    printf "  ${BOLD}[8]${RST}  📱  Simulator\n"
    printf "  ${BOLD}[9]${RST}  🐳  Docker\n"
    sep
    printf "  ${BOLD}${RED}[c]${RST}  🧹  Clean All\n"
    printf "  ${BOLD}[q]${RST}  Quit\n\n"
    printf "  Choice: "; read -r input

    case $input in
      s|S) summary ;;
      1)   menu_brew ;;
      2)   menu_node ;;
      3)   menu_pip ;;
      4)   menu_rust ;;
      5)   menu_android ;;
      6)   menu_gradle ;;
      7)   menu_xcode ;;
      8)   menu_sim ;;
      9)   menu_docker ;;
      c|C) clean_all ;;
      q|Q) printf "\n  ${DIM}Bye!${RST}\n\n"; exit 0 ;;
    esac
  done
}

main