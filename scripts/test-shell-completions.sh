#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

bash -n "$repo_root/completions/padctl.bash"
# shellcheck source=/dev/null
source "$repo_root/completions/padctl.bash"

public_commands=(
    install uninstall scan list-mappings reload switch output-profile status
    devices doctor dump config
)
for command_name in "${public_commands[@]}"; do
    grep -Fq "\"$command_name\"" "$repo_root/src/main.zig"
    grep -Fq "$command_name" "$repo_root/completions/padctl.bash"
    grep -Fq "$command_name" "$repo_root/completions/_padctl"
done
grep -Fq -- '--scope <scope>' "$repo_root/src/main.zig"
grep -Fq -- '--scope' "$repo_root/completions/padctl.bash"
grep -Fq -- '--scope[' "$repo_root/completions/_padctl"
if grep -Eq -- '--[[:alnum:]-]+=\[' "$repo_root/completions/_padctl"; then
    printf '%s\n' 'Zsh specs must complete option values as separate arguments, not --option=' >&2
    exit 1
fi
grep -Fq '_guard "^-*"' "$repo_root/completions/_padctl"
grep -Fq '_padctl_mapping_path' "$repo_root/completions/_padctl"
! grep -Fq 'setup-test-udev' "$repo_root/completions/padctl.bash"
! grep -Fq 'setup-test-udev' "$repo_root/completions/_padctl"

contains() {
    local expected=$1 item
    for item in "${COMPREPLY[@]}"; do
        [[ $item == "$expected" ]] && return 0
    done
    return 1
}

complete_case() {
    COMP_WORDS=("$@")
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    COMPREPLY=()
    _padctl
}

complete_case padctl ""
for command_name in "${public_commands[@]}"; do
    contains "$command_name"
done
! contains setup-test-udev

complete_case padctl install --s
contains --scope

complete_case padctl install --scope ""
contains system
contains user
contains package

complete_case padctl config ""
contains list
contains init
contains edit
contains test

complete_case padctl output-profile ""
contains list
contains select
contains reset

complete_case padctl dump ""
contains enable
contains export
contains clear

complete_case padctl --pid-file /tmp/pid dump export --p
contains --period

complete_case padctl --config /tmp/a config test --r
contains --raw

complete_case padctl --pid-file /tmp/pid output-profile select --d
contains --device

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
touch "$tmp_dir/device.toml"
complete_case padctl --config "$tmp_dir/dev"
contains "$tmp_dir/device.toml"

if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    mkdir -p "$tmp_dir/home" "$tmp_dir/xdg/bash-completion/completions"
    cp "$repo_root/completions/padctl.bash" \
        "$tmp_dir/xdg/bash-completion/completions/padctl.bash"
    env -i \
        PATH="$PATH" \
        HOME="$tmp_dir/home" \
        XDG_DATA_HOME="$tmp_dir/xdg" \
        bash --noprofile --norc -c '
            set -e
            source /usr/share/bash-completion/bash_completion
            [[ ${BASH_COMPLETION_VERSINFO[0]} -eq 2 ]]
            [[ ${BASH_COMPLETION_VERSINFO[1]} -eq 11 ]]
            loader_rc=0
            _completion_loader padctl || loader_rc=$?
            [[ $loader_rc -eq 124 ]]
            declare -F _padctl >/dev/null
            complete -p padctl | grep -q -- "-F _padctl"
        '
else
    printf '%s\n' 'SKIP: bash-completion framework is not installed'
fi

if command -v zsh >/dev/null 2>&1; then
    zsh -n "$repo_root/completions/_padctl"
    mkdir -p "$tmp_dir/zsh/site-functions"
    cp "$repo_root/completions/_padctl" "$tmp_dir/zsh/site-functions/_padctl"
    ZDOTDIR=$tmp_dir zsh -f -c '
        fpath=("$1" $fpath)
        autoload -Uz compinit
        # CI runners may add unrelated group-writable directories to fpath.
        # Ignore those instead of trying to prompt from this non-interactive test.
        compinit -D -i
        [[ ${_comps[padctl]-} == _padctl ]]
    ' zsh-test "$tmp_dir/zsh/site-functions"
    ZDOTDIR=$tmp_dir zsh -f -c '
        fpath=("$1" $fpath)
        autoload -Uz compinit
        compinit -D -i

        # Load the autoloaded file once with harmless completion builtins.
        _arguments() { state=command }
        _describe() { : }
        _padctl

        typeset -gi calls
        typeset -g captured
        typeset -ga desired_line
        _arguments() {
            (( calls++ ))
            if (( calls == 1 )); then
                state=arguments
                line=("${desired_line[@]}")
            else
                captured="$*"
            fi
        }

        calls=0
        captured=""
        desired_line=(select)
        _padctl_output_profile
        [[ $captured == *"--device["* ]]

        calls=0
        captured=""
        desired_line=(export)
        _padctl_dump
        [[ $captured == *"--period["* ]]
        [[ $captured == *"-o[write to a file]"* ]]

        calls=0
        captured=""
        desired_line=(test)
        _padctl_config
        [[ $captured == *"--config["* ]]
        [[ $captured == *--raw* ]]
    ' zsh-state-test "$tmp_dir/zsh/site-functions"

    if command -v script >/dev/null 2>&1 &&
        script --version 2>&1 | grep -Fq 'util-linux'; then
        zle_setup='PROMPT=; RPROMPT=; unset zle_bracketed_paste; fpath=("$PADCTL_ZSH_FPATH" $fpath); autoload -Uz compinit; compinit -D -i; bindkey "^I" complete-word; _capture_completion_buffer() { local quoted=${(q)BUFFER}; BUFFER="print -r -- CAPTURE:$quoted"; zle accept-line; }; zle -N _capture_completion_buffer; bindkey "^Xx" _capture_completion_buffer'
        zle_input=$zle_setup$'\n'
        zle_input+=$'padctl output-profile l\t\030x'
        zle_input+=$'padctl --pid-file /tmp/pid dump export --p\t\030x'
        zle_input+=$'padctl config test --m\t\030x'
        zle_input+=$'padctl config list --h\t\030x'
        zle_input+=$'exit\n'

        if ! zle_output=$(
            printf '%s' "$zle_input" |
                TERM=dumb \
                    ZDOTDIR="$tmp_dir" \
                    PADCTL_ZSH_FPATH="$tmp_dir/zsh/site-functions" \
                    script -qec 'zsh -f' /dev/null
        ); then
            printf '%s\n' 'real Zsh PTY completion test failed to run' >&2
            exit 1
        fi
        zle_captures=$(
            printf '%s\n' "$zle_output" |
                tr -d '\r' |
                grep '^CAPTURE:' || true
        )
        expected_captures=$'CAPTURE:padctl output-profile list\x20\nCAPTURE:padctl --pid-file /tmp/pid dump export --period\x20\nCAPTURE:padctl config test --mapping\x20\nCAPTURE:padctl config list --help\x20'
        if [[ $zle_captures != "$expected_captures" ]]; then
            printf '%s\n' 'unexpected real Zsh completion buffers:' >&2
            printf 'expected:\n%s\nactual:\n%s\n' "$expected_captures" "$zle_captures" >&2
            exit 1
        fi
    else
        printf '%s\n' 'SKIP: util-linux script is not installed; real Zsh PTY test not run'
    fi
else
    printf '%s\n' 'SKIP: zsh is not installed'
fi

printf '%s\n' 'shell completion tests passed'
