#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

say() {
  printf "\033[1;36m[railwyrm-install]\033[0m %s\n" "$*"
}

die() {
  printf "\033[1;31m[railwyrm-install]\033[0m %s\n" "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_cmd ruby
require_cmd gem
require_cmd bundle

INSTALL_SCOPE="${RAILWYRM_INSTALL_SCOPE:-user}"
BIN_DIR="${RAILWYRM_BIN_DIR:-$HOME/.local/bin}"

if [[ "$INSTALL_SCOPE" != "user" && "$INSTALL_SCOPE" != "system" ]]; then
  die "RAILWYRM_INSTALL_SCOPE must be 'user' or 'system'"
fi

say "Installing dependencies with Bundler"
bundle install

say "Building gem"
BUILD_OUTPUT="$(gem build railwyrm.gemspec)"
printf "%s\n" "$BUILD_OUTPUT"
GEM_FILE="$(printf "%s\n" "$BUILD_OUTPUT" | awk '/File:/ {print $2}')"

if [[ -z "$GEM_FILE" || ! -f "$ROOT_DIR/$GEM_FILE" ]]; then
  die "Could not find built gem artifact"
fi

if [[ "$INSTALL_SCOPE" == "system" ]]; then
  say "Installing gem system-wide"
  gem install --force --no-document "$ROOT_DIR/$GEM_FILE"
else
  say "Installing gem for current user"
  mkdir -p "$BIN_DIR"
  gem install --force --user-install --bindir "$BIN_DIR" --no-document "$ROOT_DIR/$GEM_FILE"
fi

if [[ "$INSTALL_SCOPE" == "user" && -x "$BIN_DIR/railwyrm" ]]; then
  say "Installed: $BIN_DIR/railwyrm"
  "$BIN_DIR/railwyrm" version
  say "Add to PATH if needed: export PATH=\"$BIN_DIR:\$PATH\""
elif command -v railwyrm >/dev/null 2>&1; then
  say "Installed: $(command -v railwyrm)"
  if ! railwyrm version; then
    say "Detected a shell shim issue. If you use rbenv, run: rbenv rehash"
  fi
else
  say "Install finished. Run 'railwyrm version' once your PATH is updated."
fi
