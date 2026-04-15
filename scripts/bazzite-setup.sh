#!/bin/bash
# bazzite-setup.sh — Full padctl setup for Bazzite (Fedora Atomic / ostree)
#
# Installs dependencies, builds padctl, and configures the system.
# Safe to run multiple times — idempotent for deps, always reinstalls padctl.
#
# Usage:
#   bash scripts/bazzite-setup.sh                    # from padctl repo
#   bash scripts/bazzite-setup.sh /path/to/padctl    # explicit repo path
#   bash scripts/bazzite-setup.sh --mapping vader5   # install a specific mapping

set -euo pipefail

# --- Configuration ---
PADCTL_REPO=""
MAPPING="${MAPPING:-}"
BRANCH="${BRANCH:-}"
PREFIX="/usr/local"
BREW_PREFIX="/home/linuxbrew/.linuxbrew"
PADCTL_GIT_URL="${PADCTL_GIT_URL:-https://github.com/BANANASJIM/padctl.git}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mapping) [[ -n "${2:-}" ]] || { echo "ERROR: --mapping requires a name" >&2; exit 1; }; MAPPING="$2"; shift 2 ;;
        --branch|-b) [[ -n "${2:-}" ]] || { echo "ERROR: --branch requires a name" >&2; exit 1; }; BRANCH="$2"; shift 2 ;;
        --repo-url) [[ -n "${2:-}" ]] || { echo "ERROR: --repo-url requires a URL" >&2; exit 1; }; PADCTL_GIT_URL="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: bash bazzite-setup.sh [repo-path] [--mapping NAME] [--branch NAME] [--repo-url URL]"
            echo ""
            echo "Options:"
            echo "  repo-path     Path to padctl repo (default: auto-detect or ~/Games/padctl)"
            echo "  --mapping     Mapping config to install and auto-apply on boot (default: prompt)"
            echo "  --branch, -b  Git branch to clone/checkout (default: repo default branch)"
            echo "  --repo-url    Git repo URL (default: BANANASJIM/padctl)"
            exit 0
            ;;
        --*)
            echo "ERROR: Unknown option: $1" >&2
            exit 1
            ;;
        *)
            if [[ -z "$PADCTL_REPO" ]]; then
                PADCTL_REPO="$1"
            fi
            shift
            ;;
    esac
done

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- 1. OS Detection ---
info "Detecting OS..."
IS_IMMUTABLE=false

if [[ -f /run/ostree-booted ]]; then
    IS_IMMUTABLE=true
    ok "Immutable OS detected (ostree)"
elif findmnt -n -o OPTIONS / 2>/dev/null | grep -q '\bro\b'; then
    # Root filesystem mounted read-only (non-ostree immutable)
    IS_IMMUTABLE=true
    ok "Immutable OS detected (read-only root)"
else
    warn "This does not appear to be an immutable OS."
    warn "This script is designed for Bazzite/Fedora Atomic."
    read -rp "Continue anyway? [y/N] " yn
    [[ "$yn" =~ ^[Yy] ]] || exit 0
fi

# --- 2. Install Homebrew (if immutable + not present) ---
if $IS_IMMUTABLE && ! command -v brew &>/dev/null; then
    info "Installing Homebrew (required for dev libraries on immutable OS)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$($BREW_PREFIX/bin/brew shellenv)"
    ok "Homebrew installed"
elif command -v brew &>/dev/null; then
    eval "$(brew shellenv 2>/dev/null)" || true
    ok "Homebrew already available"
fi

# --- 3. Install dependencies ---
info "Checking dependencies..."

install_brew_pkg() {
    local pkg="$1"
    if brew list "$pkg" &>/dev/null; then
        ok "$pkg already installed"
    else
        info "Installing $pkg via brew..."
        brew install "$pkg"
        ok "$pkg installed"
    fi
}

ZIG_BREW_PKG="zig@0.15"  # padctl requires Zig 0.15.x; 0.16+ has breaking API changes

if command -v brew &>/dev/null; then
    install_brew_pkg "$ZIG_BREW_PKG"
    install_brew_pkg libusb
    # zig@0.15 is keg-only — ensure it's on PATH for this session.
    if [[ -d "$BREW_PREFIX/opt/$ZIG_BREW_PKG/bin" ]]; then
        export PATH="$BREW_PREFIX/opt/$ZIG_BREW_PKG/bin:$PATH"
    fi
else
    # Non-brew: check if zig and libusb are available
    if ! command -v zig &>/dev/null; then
        err "zig not found. Install Zig 0.15.x from https://ziglang.org/download/"
        exit 1
    fi
    # Warn if version is 0.16+ (breaking changes)
    zig_ver="$(zig version 2>/dev/null || echo unknown)"
    case "$zig_ver" in
        0.15.*) ok "zig found: $zig_ver" ;;
        0.16.*|0.17.*|1.*)
            warn "zig $zig_ver detected — padctl requires 0.15.x (0.16+ has breaking build API changes)"
            warn "Install zig@0.15 via brew, or download from https://ziglang.org/download/"
            read -rp "Continue anyway? [y/N] " yn
            [[ "$yn" =~ ^[Yy] ]] || exit 1
            ;;
        *) ok "zig found: $zig_ver" ;;
    esac
fi

# --- 4. Locate or clone padctl repo ---
if [[ -z "$PADCTL_REPO" ]]; then
    # Try to detect: are we in the repo?
    if [[ -f "build.zig" && -d "src/cli" ]]; then
        PADCTL_REPO="$(pwd)"
    elif [[ -f "scripts/bazzite-setup.sh" ]]; then
        PADCTL_REPO="$(cd .. && pwd)"
    else
        PADCTL_REPO="$HOME/Games/padctl"
    fi
fi

if [[ -d "$PADCTL_REPO/.git" ]]; then
    info "Updating existing repo at $PADCTL_REPO..."
    if [[ -n "$BRANCH" ]]; then
        git -C "$PADCTL_REPO" fetch origin 2>/dev/null || true
        git -C "$PADCTL_REPO" checkout "$BRANCH" 2>/dev/null || warn "checkout $BRANCH failed"
        git -C "$PADCTL_REPO" pull --ff-only 2>/dev/null || warn "git pull failed (might have local changes)"
    else
        git -C "$PADCTL_REPO" pull --ff-only 2>/dev/null || warn "git pull failed (might have local changes)"
    fi
    ok "Repo up to date"
elif [[ -f "$PADCTL_REPO/build.zig" ]]; then
    ok "Using existing repo at $PADCTL_REPO (not a git repo)"
else
    info "Cloning padctl to $PADCTL_REPO..."
    clone_args=(clone)
    if [[ -n "$BRANCH" ]]; then
        clone_args+=(-b "$BRANCH")
    fi
    clone_args+=("$PADCTL_GIT_URL" "$PADCTL_REPO")
    git "${clone_args[@]}"
    ok "Repo cloned${BRANCH:+ (branch: $BRANCH)}"
fi

cd "$PADCTL_REPO"

# --- 5. Build ---
info "Building padctl (ReleaseSafe) with zig $(zig version)..."
build_args=(-Doptimize=ReleaseSafe)
if [[ -d "$BREW_PREFIX" ]]; then
    build_args+=(--search-prefix "$BREW_PREFIX")
fi
zig build "${build_args[@]}"
ok "Build complete"

# --- 6. Stop existing service (if running) ---
if systemctl is-active padctl.service &>/dev/null; then
    info "Stopping existing padctl service..."
    sudo systemctl stop padctl.service 2>/dev/null || true
    ok "Service stopped"
fi

# --- 6b. Prompt for mapping if not specified ---
if [[ -z "$MAPPING" && -d "$PADCTL_REPO/mappings" ]]; then
    if [[ -t 0 ]]; then
        echo ""
        info "Available mapping configs:"
        mapfile -t available_mappings < <(find "$PADCTL_REPO/mappings" -name '*.toml' -printf '%f\n' | sed 's/\.toml$//' | sort)
        for i in "${!available_mappings[@]}"; do
            echo "  $((i+1)). ${available_mappings[$i]}"
        done
        echo "  0. Skip (no mapping)"
        read -rp "Select mapping to install [0]: " choice || choice=0
        if [[ -n "$choice" && "$choice" != "0" ]] && (( choice >= 1 && choice <= ${#available_mappings[@]} )); then
            MAPPING="${available_mappings[$((choice-1))]}"
            ok "Selected mapping: $MAPPING"
        else
            info "Skipping mapping installation"
        fi
    else
        info "Non-interactive shell detected; skipping mapping prompt (use --mapping <name>)"
    fi
fi

# --- 7. Install (always reinstall) ---
info "Installing padctl..."
install_args=(install --prefix "$PREFIX")
if $IS_IMMUTABLE; then
    install_args+=(--immutable)
fi
if [[ -n "$MAPPING" ]]; then
    install_args+=(--mapping "$MAPPING" --force-mapping --force-binding)
fi
sudo ./zig-out/bin/padctl "${install_args[@]}"
ok "padctl installed to $PREFIX"

# --- 7b. Apply mapping to the running daemon (config.toml persists for future boots,
#         but the already-running daemon needs an explicit switch for the current session) ---
if [[ -n "$MAPPING" ]]; then
    info "Waiting for daemon to initialize..."
    sleep 3
    if "$PREFIX/bin/padctl" switch "$MAPPING" --socket /run/padctl/padctl.sock 2>/dev/null; then
        ok "Mapping applied: $MAPPING (persisted for future boots via /etc/padctl/config.toml)"
    else
        warn "Could not apply mapping to running daemon (it will auto-apply on next boot). Run manually: padctl switch $MAPPING"
    fi
fi

# --- 8. Verify ---
echo ""
info "Verifying installation..."

# Check binary
if [[ -x "$PREFIX/bin/padctl" ]]; then
    ok "Binary: $PREFIX/bin/padctl"
else
    err "Binary not found at $PREFIX/bin/padctl"
fi

# Check service
if systemctl is-enabled padctl.service &>/dev/null; then
    ok "Service: enabled"
else
    warn "Service: not enabled (may need manual enable)"
fi

if systemctl is-active padctl.service &>/dev/null; then
    ok "Service: running"
else
    warn "Service: not running (plug in a controller)"
fi

# Check resume service
if systemctl is-enabled padctl-resume.service &>/dev/null; then
    ok "Resume service: enabled"
fi

# Check udev rules
for rules_file in 60-padctl.rules 61-padctl-driver-block.rules; do
    if $IS_IMMUTABLE; then
        rules_path="/etc/udev/rules.d/$rules_file"
    else
        rules_path="$PREFIX/lib/udev/rules.d/$rules_file"
    fi
    if [[ -f "$rules_path" ]]; then
        ok "Udev rules: $rules_path"
    fi
done

# Check mapping
if [[ -n "$MAPPING" && -f "/etc/padctl/mappings/${MAPPING}.toml" ]]; then
    ok "Mapping: /etc/padctl/mappings/${MAPPING}.toml"
fi

# Check device→mapping binding (auto-apply on boot)
if [[ -n "$MAPPING" && -f "/etc/padctl/config.toml" ]]; then
    if grep -q "default_mapping.*=.*\"${MAPPING}\"" /etc/padctl/config.toml 2>/dev/null; then
        ok "Binding: /etc/padctl/config.toml → $MAPPING (auto-applies on boot)"
    else
        warn "Binding: /etc/padctl/config.toml exists but does not bind to $MAPPING"
    fi
fi

echo ""
ok "Setup complete! Plug in your controller and run: padctl status"
