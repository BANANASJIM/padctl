#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PADCTL_BAZZITE_TEST_LIB_ONLY=1
set --
# shellcheck source=scripts/bazzite-setup.sh
source "$SCRIPT_DIR/bazzite-setup.sh"
unset PADCTL_BAZZITE_TEST_LIB_ONLY

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

write_fake_git() {
    local fakebin="$1"
    mkdir -p "$fakebin"
    cat >"$fakebin/git" <<'FAKE_GIT'
#!/usr/bin/env bash
set -euo pipefail

repo=""
if [[ "${1:-}" == "-C" ]]; then
    repo="$2"
    shift 2
fi

cmd="${1:-}"
[[ $# -gt 0 ]] && shift

state_dir() { printf '%s/.fakegit' "$repo"; }
read_state() { cat "$(state_dir)/$1"; }
write_state() { printf '%s\n' "$2" >"$(state_dir)/$1"; }

case "$cmd" in
    diff)
        if [[ -f "$(state_dir)/dirty" ]]; then
            exit 1
        fi
        exit 0
        ;;
    ls-files)
        if [[ -f "$(state_dir)/untracked" ]]; then
            echo "untracked.txt"
        fi
        exit 0
        ;;
    symbolic-ref)
        echo "origin/main"
        exit 0
        ;;
    rev-parse)
        if [[ "${1:-}" == "--abbrev-ref" ]]; then
            if [[ -f "$(state_dir)/upstream" ]]; then
                read_state upstream
                exit 0
            fi
            exit 1
        fi
        case "${1:-}" in
            HEAD) read_state head ;;
            origin/main) read_state origin ;;
            '@{upstream}') read_state origin ;;
            *) exit 1 ;;
        esac
        ;;
    branch)
        if [[ "${1:-}" == "--show-current" ]]; then
            read_state branch
            exit 0
        fi
        exit 1
        ;;
    fetch)
        exit 0
        ;;
    show-ref)
        ref="${*: -1}"
        case "$ref" in
            refs/heads/main) test -f "$(state_dir)/local-main" ;;
            refs/remotes/origin/main) test -f "$(state_dir)/remote-main" ;;
            *) exit 1 ;;
        esac
        ;;
    stash)
        touch "$(state_dir)/stashed"
        rm -f "$(state_dir)/dirty" "$(state_dir)/untracked"
        exit 0
        ;;
    checkout)
        if [[ "${1:-}" == "-B" ]]; then
            branch="$2"
            target="$3"
            write_state branch "$branch"
            touch "$(state_dir)/local-$branch"
            if [[ "$target" == "origin/main" ]]; then
                read_state origin >"$(state_dir)/head"
                printf 'new\n' >"$repo/version.txt"
            fi
            exit 0
        fi
        write_state branch "$1"
        exit 0
        ;;
    reset)
        if [[ "${2:-}" == "origin/main" ]]; then
            read_state origin >"$(state_dir)/head"
            printf 'new\n' >"$repo/version.txt"
            exit 0
        fi
        exit 1
        ;;
    pull)
        if [[ -f "$(state_dir)/pull-fails" ]]; then
            exit 1
        fi
        if [[ -f "$(state_dir)/pull-noop" ]]; then
            # Simulates "Already up to date" — exits 0 but HEAD does not move.
            exit 0
        fi
        read_state origin >"$(state_dir)/head"
        printf 'new\n' >"$repo/version.txt"
        exit 0
        ;;
    *)
        echo "fake git: unsupported command: $cmd $*" >&2
        exit 127
        ;;
esac
FAKE_GIT
    chmod +x "$fakebin/git"
}

create_fake_repo() {
    local repo="$1"
    local head="$2"
    local origin="$3"
    local content="$4"
    local dirty="${5:-false}"

    mkdir -p "$repo/.fakegit"
    printf '%s\n' "$head" >"$repo/.fakegit/head"
    printf '%s\n' "$origin" >"$repo/.fakegit/origin"
    printf 'main\n' >"$repo/.fakegit/branch"
    printf 'origin/main\n' >"$repo/.fakegit/upstream"
    touch "$repo/.fakegit/local-main" "$repo/.fakegit/remote-main" "$repo/.fakegit/pull-fails"
    printf '%s\n' "$content" >"$repo/version.txt"
    if [[ "$dirty" == "true" ]]; then
        touch "$repo/.fakegit/dirty"
    fi
}

run_fake_git_tests() {
    local fakebin="$tmpdir/fakebin"
    local old_path="$PATH"
    write_fake_git "$fakebin"
    export PATH="$fakebin:$PATH"

    local repo="$tmpdir/fake-managed"
    create_fake_repo "$repo" "old-head" "new-head" "local edit" true
    update_existing_repo "$repo" "" true
    assert_file_equals "$repo/version.txt" "new"
    [[ "$(git -C "$repo" rev-parse HEAD)" == "new-head" ]] || {
        echo "fake managed repo did not reset to origin/main" >&2
        exit 1
    }
    [[ -f "$repo/.fakegit/stashed" ]] || {
        echo "fake managed repo did not stash local changes" >&2
        exit 1
    }

    repo="$tmpdir/fake-user"
    create_fake_repo "$repo" "old-head" "new-head" "local edit" true
    update_existing_repo "$repo" "" false
    assert_file_equals "$repo/version.txt" "local edit"
    [[ "$(git -C "$repo" rev-parse HEAD)" == "old-head" ]] || {
        echo "fake user repo was unexpectedly reset" >&2
        exit 1
    }

    repo="$tmpdir/fake-user-branch"
    create_fake_repo "$repo" "local-head" "new-head" "local commit" false
    update_existing_repo "$repo" "main" false
    [[ "$(git -C "$repo" rev-parse HEAD)" == "local-head" ]] || {
        echo "fake user branch was unexpectedly reset" >&2
        exit 1
    }

    export PATH="$old_path"
}

git_quiet() {
    git "$@" >/dev/null 2>&1
}

configure_repo() {
    local repo="$1"
    git_quiet -C "$repo" config user.name "padctl test"
    git_quiet -C "$repo" config user.email "padctl-test@example.invalid"
}

create_origin_with_clone() {
    local origin="$1"
    local seed="$2"
    local clone="$3"

    git_quiet init --bare --initial-branch=main "$origin"
    git_quiet clone "$origin" "$seed"
    configure_repo "$seed"
    printf 'old\n' >"$seed/version.txt"
    git_quiet -C "$seed" add version.txt
    git_quiet -C "$seed" commit -m "initial"
    git_quiet -C "$seed" push -u origin main
    git_quiet --git-dir="$origin" symbolic-ref HEAD refs/heads/main

    git_quiet clone "$origin" "$clone"
    configure_repo "$clone"
}

advance_origin() {
    local seed="$1"
    printf 'new\n' >"$seed/version.txt"
    git_quiet -C "$seed" commit -am "advance"
    git_quiet -C "$seed" push
}

assert_file_equals() {
    local path="$1"
    local expected="$2"
    local actual
    actual="$(cat "$path")"
    if [[ "$actual" != "$expected" ]]; then
        echo "expected $path to contain '$expected', got '$actual'" >&2
        exit 1
    fi
}

test_managed_dirty_repo_recovers_from_pull_failure() {
    local root="$tmpdir/managed"
    local origin="$root/origin.git"
    local seed="$root/seed"
    local repo="$root/home/Games/padctl"

    mkdir -p "$(dirname "$repo")"
    create_origin_with_clone "$origin" "$seed" "$repo"
    printf 'local edit\n' >"$repo/version.txt"
    advance_origin "$seed"

    # This is the #320 failure mode: the old script ran this pull, warned, and
    # then kept building the stale checkout.
    if timeout 10 git -C "$repo" pull --ff-only >/dev/null 2>&1; then
        echo "bug fixture invalid: dirty checkout unexpectedly fast-forwarded" >&2
        exit 1
    fi

    update_existing_repo "$repo" "" true

    assert_file_equals "$repo/version.txt" "new"
    if [[ "$(git -C "$repo" rev-parse HEAD)" != "$(git -C "$repo" rev-parse origin/main)" ]]; then
        echo "managed repo did not reset to origin/main" >&2
        exit 1
    fi
    if ! git -C "$repo" stash list | grep -q "padctl bazzite setup auto-stash before update"; then
        echo "managed repo local changes were not preserved in a stash" >&2
        exit 1
    fi
}

test_user_repo_is_not_reset_after_pull_failure() {
    local root="$tmpdir/user"
    local origin="$root/origin.git"
    local seed="$root/seed"
    local repo="$root/repo"

    create_origin_with_clone "$origin" "$seed" "$repo"
    printf 'local edit\n' >"$repo/version.txt"
    advance_origin "$seed"

    update_existing_repo "$repo" "" false

    assert_file_equals "$repo/version.txt" "local edit"
    if [[ "$(git -C "$repo" rev-parse HEAD)" == "$(git -C "$repo" rev-parse origin/main)" ]]; then
        echo "user-managed repo was unexpectedly reset to origin/main" >&2
        exit 1
    fi
}

test_user_branch_is_not_reset_to_remote() {
    local root="$tmpdir/user-branch"
    local origin="$root/origin.git"
    local seed="$root/seed"
    local repo="$root/repo"
    local local_head

    create_origin_with_clone "$origin" "$seed" "$repo"
    printf 'local commit\n' >"$repo/version.txt"
    git_quiet -C "$repo" commit -am "local commit"
    local_head="$(git -C "$repo" rev-parse HEAD)"
    advance_origin "$seed"

    update_existing_repo "$repo" "main" false

    if [[ "$(git -C "$repo" rev-parse HEAD)" != "$local_head" ]]; then
        echo "user-managed branch was unexpectedly reset to origin/main" >&2
        exit 1
    fi
}

# Regression test for issue #320: managed repo where git pull returns success (exit 0)
# but HEAD does not advance to origin's SHA ("Already up to date" silent no-op).
# Before the fix, the script continued to the build step using the stale checkout.
# After the fix, update_existing_repo must return non-zero with a clear error.
test_managed_silent_noop_pull_is_detected() {
    local fakebin="$tmpdir/fakebin-noop"
    local old_path="$PATH"
    write_fake_git "$fakebin"
    export PATH="$fakebin:$PATH"

    local repo="$tmpdir/fake-managed-noop"
    # Local HEAD is old; origin has advanced. pull returns 0 but does NOT move HEAD.
    create_fake_repo "$repo" "old-head" "new-head" "old content" false
    # create_fake_repo adds pull-fails; remove it so pull returns 0 (the silent-noop case).
    rm -f "$repo/.fakegit/pull-fails"
    touch "$repo/.fakegit/pull-noop"

    local update_exit=0
    update_existing_repo "$repo" "" true || update_exit=$?

    export PATH="$old_path"

    if [[ "$update_exit" -eq 0 ]]; then
        echo "FAIL: update_existing_repo returned 0 on silent-noop pull (issue #320 regression)" >&2
        exit 1
    fi
    # HEAD must still be old-head (we did not silently proceed)
    local actual_head
    actual_head="$(PATH="$fakebin:$PATH" git -C "$repo" rev-parse HEAD)"
    if [[ "$actual_head" != "old-head" ]]; then
        echo "FAIL: HEAD changed silently in noop test (expected old-head, got $actual_head)" >&2
        exit 1
    fi
}

bash -n "$SCRIPT_DIR/bazzite-setup.sh"
test_managed_silent_noop_pull_is_detected
if command -v git >/dev/null 2>&1; then
    test_managed_dirty_repo_recovers_from_pull_failure
    test_user_repo_is_not_reset_after_pull_failure
    test_user_branch_is_not_reset_to_remote
else
    run_fake_git_tests
fi

echo "bazzite setup regression tests passed"
