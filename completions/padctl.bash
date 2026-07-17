# Bash completion for padctl.

_padctl_complete_files()
{
    local candidate
    COMPREPLY=()
    while IFS= read -r candidate; do
        COMPREPLY+=("$candidate")
    done < <(compgen -f -- "$cur")
    compopt -o filenames 2>/dev/null || true
}

_padctl_complete_dirs()
{
    local candidate
    COMPREPLY=()
    while IFS= read -r candidate; do
        COMPREPLY+=("$candidate")
    done < <(compgen -d -- "$cur")
    compopt -o filenames 2>/dev/null || true
}

_padctl_complete_words()
{
    COMPREPLY=( $(compgen -W "$1" -- "$cur") )
}

_padctl()
{
    local cur prev command subcommand word i command_index
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=""
    if (( COMP_CWORD > 0 )); then
        prev=${COMP_WORDS[COMP_CWORD-1]}
    fi

    command=""
    command_index=-1
    for ((i = 1; i < COMP_CWORD; i++)); do
        word=${COMP_WORDS[i]}
        case "$word" in
            --config|--config-dir|--mapping|--validate|--pid-file|--output)
                ((i++))
                ;;
            --doc-gen|--help|-h|--version|-V)
                ;;
            -*)
                ;;
            *)
                command=$word
                command_index=$i
                break
                ;;
        esac
    done

    case "$prev" in
        --scope)
            _padctl_complete_words "system user package"
            return
            ;;
        --prefix|--destdir|--config-dir|--output)
            _padctl_complete_dirs
            return
            ;;
        --config|--validate|--pid-file|--socket|-o)
            _padctl_complete_files
            return
            ;;
        --mapping)
            if [[ $command != install && $command != uninstall ]]; then
                _padctl_complete_files
            else
                COMPREPLY=()
            fi
            return
            ;;
        --device|--pid|--period)
            COMPREPLY=()
            return
            ;;
    esac

    if [[ -z $command ]]; then
        _padctl_complete_words "install uninstall scan list-mappings reload switch output-profile status devices doctor dump config --config --config-dir --mapping --validate --pid-file --doc-gen --output --help -h --version -V"
        return
    fi

    case "$command" in
        install)
            _padctl_complete_words "--prefix --destdir --immutable --no-immutable --mapping --force-mapping --force-binding --user-service --no-user-service --no-enable --no-start --scope --help -h"
            ;;
        uninstall)
            _padctl_complete_words "--prefix --destdir --immutable --no-immutable --mapping --scope --help -h"
            ;;
        scan|list-mappings)
            _padctl_complete_words "--config-dir --help -h"
            ;;
        reload)
            _padctl_complete_words "--pid --help -h"
            ;;
        switch)
            _padctl_complete_words "--persist --device --socket --help -h"
            ;;
        status|devices|doctor)
            _padctl_complete_words "--socket --help -h"
            ;;
        output-profile)
            subcommand=""
            if (( COMP_CWORD > command_index + 1 )); then
                subcommand=${COMP_WORDS[command_index+1]}
            fi
            if [[ -z $subcommand || $subcommand == -* ]]; then
                _padctl_complete_words "list select reset --help -h"
            else
                _padctl_complete_words "--device --help -h"
            fi
            ;;
        dump)
            subcommand=""
            if (( COMP_CWORD > command_index + 1 )); then
                subcommand=${COMP_WORDS[command_index+1]}
            fi
            if [[ -z $subcommand || $subcommand == -* ]]; then
                _padctl_complete_words "enable disable status export clear --help -h"
            elif [[ $subcommand == export ]]; then
                _padctl_complete_words "--period --socket -o --help -h"
            else
                _padctl_complete_words "--socket --help -h"
            fi
            ;;
        config)
            subcommand=""
            if (( COMP_CWORD > command_index + 1 )); then
                subcommand=${COMP_WORDS[command_index+1]}
            fi
            if [[ -z $subcommand || $subcommand == -* ]]; then
                _padctl_complete_words "list init edit test --help -h"
            else
                case "$subcommand" in
                    init)
                        _padctl_complete_words "--device --help -h"
                        ;;
                    test)
                        _padctl_complete_words "--config --mapping --raw --help -h"
                        ;;
                    *)
                        _padctl_complete_words "--help -h"
                        ;;
                esac
            fi
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

complete -F _padctl padctl
