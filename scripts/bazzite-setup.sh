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
PADCTL_REPO_AUTO_MANAGED=false

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
                PADCTL_REPO_AUTO_MANAGED=false
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

repo_is_dirty() {
    local repo="$1"
    ! git -C "$repo" diff --quiet \
        || ! git -C "$repo" diff --cached --quiet \
        || [[ -n "$(git -C "$repo" ls-files --others --exclude-standard)" ]]
}

origin_head_ref() {
    local repo="$1"
    local ref
    ref="$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [[ -n "$ref" ]]; then
        echo "$ref"
    else
        echo "origin/main"
    fi
}

current_upstream_ref() {
    local repo="$1"
    git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true
}

run_user_systemctl() {
    local output status
    if output="$(systemctl --user "$@" 2>&1 >/dev/null)"; then
        return 0
    fi
    status=$?
    if [[ "$output" != *"Failed to connect to bus"* && "$output" != *"No medium found"* ]]; then
        return "$status"
    fi

    local uid user runtime bus
    uid="$(id -u 2>/dev/null || true)"
    user="$(id -un 2>/dev/null || true)"
    [[ -n "$uid" && -n "$user" ]] || return 1

    runtime="/run/user/$uid"
    bus="$runtime/bus"
    [[ -S "$bus" ]] || return 1
    command -v sudo >/dev/null 2>&1 || return 1

    sudo -u "$user" \
        env XDG_RUNTIME_DIR="$runtime" DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
        systemctl --user "$@" >/dev/null 2>&1
}

legacy_system_service_present() {
    systemctl is-active --quiet padctl.service >/dev/null 2>&1 \
        || systemctl is-enabled --quiet padctl.service >/dev/null 2>&1
}

stop_existing_padctl_services() {
    if run_user_systemctl is-active padctl.service; then
        info "Stopping existing user padctl service..."
        if run_user_systemctl stop padctl.service; then
            ok "User service stopped"
        else
            warn "Could not stop user padctl.service; install will still try to restart it"
        fi
    fi

    if legacy_system_service_present; then
        warn "Stopping legacy system padctl.service to avoid a stale daemon grabbing the controller"
        sudo systemctl stop padctl.service >/dev/null 2>&1 || warn "Could not stop legacy system padctl.service"
        sudo systemctl disable padctl.service >/dev/null 2>&1 || warn "Could not disable legacy system padctl.service"
        sudo systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

ensure_user_padctl_service() {
    if ! run_user_systemctl daemon-reload; then
        warn "Could not reload user systemd manager"
    fi
    if ! run_user_systemctl enable padctl.service; then
        warn "Could not enable user padctl.service"
    fi
    if run_user_systemctl restart padctl.service; then
        ok "User service restarted"
    elif run_user_systemctl start padctl.service; then
        ok "User service started"
    else
        warn "Could not start user padctl.service — check 'systemctl --user status padctl.service'"
    fi
}

sync_managed_repo_to_remote() {
    local repo="$1"
    local branch="$2"
    local target_ref current_branch

    git -C "$repo" fetch origin >/dev/null 2>&1

    if [[ -n "$branch" ]]; then
        target_ref="origin/$branch"
        if ! git -C "$repo" show-ref --verify --quiet "refs/remotes/$target_ref"; then
            err "remote branch not found: $target_ref"
            return 1
        fi
        current_branch="$branch"
    else
        target_ref="$(current_upstream_ref "$repo")"
        if [[ -z "$target_ref" ]]; then
            target_ref="$(origin_head_ref "$repo")"
        fi
        current_branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
        if [[ -z "$current_branch" && "$target_ref" == origin/* ]]; then
            current_branch="${target_ref#origin/}"
        fi
    fi

    warn "Fast-forward update failed; resetting managed checkout to $target_ref"
    if repo_is_dirty "$repo"; then
        warn "Preserving local changes in git stash before reset"
        git -C "$repo" stash push --include-untracked \
            -m "padctl bazzite setup auto-stash before update $(date -u +%Y%m%dT%H%M%SZ)" >/dev/null
    fi

    if [[ -n "$current_branch" ]]; then
        git -C "$repo" checkout -B "$current_branch" "$target_ref" >/dev/null 2>&1
    else
        git -C "$repo" checkout --detach "$target_ref" >/dev/null 2>&1
    fi
    git -C "$repo" reset --hard "$target_ref" >/dev/null 2>&1
}

update_existing_repo() {
    local repo="$1"
    local branch="$2"
    local auto_managed="$3"

    repo_updated=false
    if [[ -n "$branch" ]]; then
        git -C "$repo" fetch origin >/dev/null 2>&1
        if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
            git -C "$repo" checkout "$branch" >/dev/null 2>&1 || warn "checkout $branch failed"
        elif git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
            git -C "$repo" checkout -B "$branch" "origin/$branch" >/dev/null 2>&1 || warn "checkout $branch failed"
        else
            warn "branch not found locally or on origin: $branch"
        fi
        if timeout 10 git -C "$repo" pull --ff-only >/dev/null 2>&1; then
            repo_updated=true
        else
            warn "git pull failed (might have local changes)"
            if $auto_managed; then
                sync_managed_repo_to_remote "$repo" "$branch"
                repo_updated=true
            fi
        fi
    else
        # Only pull if on a branch that tracks a remote (skip for local-only branches).
        if git -C "$repo" rev-parse --abbrev-ref '@{upstream}' &>/dev/null; then
            if timeout 10 git -C "$repo" pull --ff-only >/dev/null 2>&1; then
                repo_updated=true
            else
                warn "git pull failed (might have local changes)"
                if $auto_managed; then
                    sync_managed_repo_to_remote "$repo" ""
                    repo_updated=true
                fi
            fi
        elif $auto_managed; then
            sync_managed_repo_to_remote "$repo" ""
            repo_updated=true
        else
            info "Local branch with no upstream — skipping pull"
        fi
    fi
}

if [[ "${PADCTL_BAZZITE_TEST_LIB_ONLY:-}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi

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
    # Pin zig@0.15 — padctl does not yet support 0.16+
    # Versioned formulas are keg-only: install then prepend opt path to PATH
    if brew list zig@0.15 &>/dev/null; then
        ok "zig@0.15 already installed"
    else
        info "Installing zig@0.15 via brew..."
        brew install zig@0.15 || brew install zig
        ok "zig@0.15 installed"
    fi
    export PATH="$(brew --prefix)/opt/zig@0.15/bin:$PATH"
    ok "zig on PATH: $(zig version)"
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
    # padctl requires Zig 0.15.x. Reject anything else upfront so users hit a
    # clear error instead of a cryptic build failure downstream.
    if ! zig_ver="$(zig version 2>/dev/null)"; then
        err "failed to determine zig version"
        exit 1
    fi
    case "$zig_ver" in
        0.15.*) ok "zig found: $zig_ver" ;;
        *)
            # The second block below enforces a hard exit for anything
            # outside 0.15.x, so a "Continue anyway?" prompt here would
            # only ever delay the same exit. Keep the messaging but don't
            # pretend the user has a choice.
            err "zig $zig_ver detected — padctl requires 0.15.x"
            err "Install zig@0.15 via brew, or download from https://ziglang.org/download/"
            exit 1
            ;;
    esac
fi

# Verify Zig version >= 0.15.0
ZIG_VER=$(zig version 2>/dev/null || echo "0.0.0")
ZIG_MAJOR=$(echo "$ZIG_VER" | cut -d. -f1)
ZIG_MINOR=$(echo "$ZIG_VER" | cut -d. -f2)
if [ "$ZIG_MAJOR" -eq 0 ] && [ "$ZIG_MINOR" -lt 15 ]; then
    err "padctl requires Zig 0.15.x, found $ZIG_VER"
    echo "Install from https://ziglang.org/download/ or update Homebrew formula"
    exit 1
elif [ "$ZIG_MAJOR" -eq 0 ] && [ "$ZIG_MINOR" -gt 15 ]; then
    err "padctl does not yet support Zig $ZIG_VER — please use Zig 0.15.x"
    echo "Install via: brew install zig@0.15"
    exit 1
fi
ok "Zig version $ZIG_VER meets requirement (0.15.x)"

# --- 4. Locate or clone padctl repo ---
if [[ -z "$PADCTL_REPO" ]]; then
    # Try to detect: are we in the repo?
    if [[ -f "build.zig" && -d "src/cli" ]]; then
        PADCTL_REPO="$(pwd)"
    elif [[ -f "scripts/bazzite-setup.sh" ]]; then
        PADCTL_REPO="$(cd .. && pwd)"
    else
        PADCTL_REPO="$HOME/Games/padctl"
        PADCTL_REPO_AUTO_MANAGED=true
    fi
fi

if [[ -d "$PADCTL_REPO/.git" ]]; then
    info "Updating existing repo at $PADCTL_REPO..."
    update_existing_repo "$PADCTL_REPO" "$BRANCH" "$PADCTL_REPO_AUTO_MANAGED"
    if $repo_updated; then
        ok "Repo up to date"
    else
        info "Using existing repo state"
    fi
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

# --- 6. Stop existing services before overwriting the binary ---
stop_existing_padctl_services

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

# --- 7b. Guarantee the daemon is running as the invoking user ---
# `padctl install` runs via sudo (writes to /usr/local, /etc), so the
# `systemctl --user ...` trio it invokes internally executes as root and
# does not reliably reach the invoking user's systemd instance. Redo the
# daemon-reload/enable/restart sequence here from the user's shell so the
# freshly-installed unit files take effect and the IPC socket is bound
# before we apply the mapping and verify.
info "Ensuring daemon is running as user..."
ensure_user_padctl_service

# --- 7c. Apply mapping to the running daemon (config.toml persists for future boots,
#         but the already-running daemon needs an explicit switch for the current session).
#         Don't pin --socket to the system path — user-service installs bind
#         their IPC socket under $XDG_RUNTIME_DIR (/run/user/<uid>/padctl.sock),
#         and the CLI's default resolver finds it correctly from the user shell.
#         The daemon needs a few seconds post-restart to run device init + bind
#         its IPC socket, so retry a few times before giving up. "no-devices"
#         is a permanent error for this session (no retry will help) — the
#         binding in /etc/padctl/config.toml still takes effect on the next
#         hot-plug, so we short-circuit with a clearer message. ---
if [[ -n "$MAPPING" ]]; then
    mapping_applied=false
    no_devices=false
    for attempt in 1 2 3 4 5 6; do
        sleep 1
        # set -euo pipefail is active; a bare `x=$(cmd)` triggers script
        # exit on non-zero from cmd before the `$?` check can fire, so we
        # use the if-form which `set -e` explicitly ignores.
        if switch_output=$("$PREFIX/bin/padctl" switch "$MAPPING" 2>&1); then
            mapping_applied=true
            break
        fi
        if [[ "$switch_output" == *"no-devices"* ]]; then
            no_devices=true
            break
        fi
    done
    if $mapping_applied; then
        ok "Mapping applied: $MAPPING (persisted for future boots via /etc/padctl/config.toml)"
    elif $no_devices; then
        info "No controller currently connected — mapping will auto-apply via /etc/padctl/config.toml when you plug it in."
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
if run_user_systemctl is-enabled padctl.service; then
    ok "Service: enabled"
else
    warn "Service: not enabled (may need manual enable)"
fi

if run_user_systemctl is-active padctl.service; then
    ok "Service: running"
else
    # The daemon should always be running after a successful install — it
    # waits for hotplug internally and does NOT require a controller to be
    # present at startup. If we reach this branch, something failed above.
    warn "Service: not running — check 'systemctl --user status padctl' and 'journalctl --user -u padctl -n 30'"
fi

# padctl-resume.service was removed in issue #131 Problem B fix —
# the udev padctl-reconnect hook handles post-suspend reconnects.
# Nothing to verify here.

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
