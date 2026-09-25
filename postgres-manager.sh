#!/usr/bin/env bash
set -euo pipefail

BREW_PREFIX="$(brew --prefix)"

find_pg_dir() {
  find "$BREW_PREFIX/var" -maxdepth 1 -type d -name "postgres*" 2>/dev/null | head -n 1
}

find_pg_services() {
  brew services list | awk '$1 ~ /^postgres/ {print $1}'
}

find_pg_formulae() {
  # Matches postgresql / postgresql@14 etc, not postgis/postgrest/etc.
  brew list --formula 2>/dev/null | grep -E '^postgresql(@[0-9]+)?$' || true
}

reset_postgres() {
  local pg_dir pg_service
  pg_dir="$(find_pg_dir)"
  if [ -z "$pg_dir" ]; then
    echo "Error: Could not find Homebrew PostgreSQL data directory in $BREW_PREFIX/var/"
    return 1
  fi
  pg_service="$(basename "$pg_dir")"

  echo "--------------------------------------------------------"
  echo "WARNING: This will permanently delete ALL local databases!"
  echo "Target directory: $pg_dir"
  echo "--------------------------------------------------------"
  read -p "Are you sure you want to reset PostgreSQL? (y/N): " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }

  echo "--> Stopping $pg_service..."
  brew services stop "$pg_service" || true

  echo "--> Wiping database files..."
  rm -rf "$pg_dir"

  echo "--> Initializing fresh database..."
  initdb --locale=utf8 "$pg_dir"

  echo "--> Starting $pg_service..."
  brew services start "$pg_service"

  echo "--> Success! PostgreSQL has been reset to a completely clean state."
}

remove_postgres() {
  echo "--------------------------------------------------------"
  echo "WARNING: This will completely uninstall PostgreSQL and delete"
  echo "all data, logs, config, and psql history!"
  echo "--------------------------------------------------------"
  read -p "Are you sure you want to remove PostgreSQL entirely? (y/N): " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || { echo "Aborted."; return 0; }

  echo "--> Stopping PostgreSQL services..."
  find_pg_services | xargs -I {} brew services stop {} 2>/dev/null || true

  echo "--> Uninstalling PostgreSQL packages..."
  find_pg_formulae | xargs -I {} brew uninstall --force {} 2>/dev/null || true

  echo "--> Removing unused Homebrew dependencies..."
  brew autoremove || true

  echo "--> Deleting data, logs, and configuration files..."
  rm -rf "$BREW_PREFIX/var/"postgres*
  rm -rf "$BREW_PREFIX/etc/"postgres*
  rm -rf "$BREW_PREFIX/var/log/"postgres*
  rm -f ~/.psql_history

  echo "--> Done! PostgreSQL has been completely removed from your system."
}

echo "PostgreSQL Manager"
echo "1) Reset  (wipe data, keep install)"
echo "2) Remove (full uninstall)"
echo "3) Cancel"
read -p "Choose an option [1-3]: " -n 1 -r choice
echo

case "$choice" in
  1) reset_postgres ;;
  2) remove_postgres ;;
  *) echo "Cancelled." ;;
esac