# Bash completion for bundle.sh and unbundle.sh

_bundle_sh() {
    local cur prev opts base
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Basic options
    opts="--output -o --force -f --all -a --version -v --help -h \
          --no-git-ignore --include-hidden --include-build --include-binary \
          --include-empty-dirs --exclude= --exclude-pattern= --build-dirs="

    # Common build directory patterns
    local build_patterns="build/ target/ dist/ out/ \
                         node_modules/ \
                         bin/ obj/ \
                         __pycache__/ .pytest_cache/ venv/ \
                         .gradle/ .kotlin/ \
                         cmake-build/ bazel-out/"

    # Handle option arguments
    case $prev in
        -o|--output)
            # Complete with txt files and directories
            _filedir 'txt'
            return 0
            ;;
        --exclude)
            # Complete with existing files and directories
            _filedir
            return 0
            ;;
        --exclude-pattern)
            # Common file patterns
            COMPREPLY=( $( compgen -W "*.txt *.log *.tmp *.bak" -- "$cur" ) )
            return 0
            ;;
        --build-dirs)
            # Complete with common build directory patterns
            COMPREPLY=( $( compgen -W "$build_patterns" -- "$cur" ) )
            return 0
            ;;
    esac

    # Handle options with attached arguments
    case $cur in
        --output=*)
            # Complete filename after equals sign
            cur="${cur#*=}"
            _filedir 'txt'
            return 0
            ;;
        --exclude=*)
            # Complete filename after equals sign
            cur="${cur#*=}"
            _filedir
            return 0
            ;;
        --exclude-pattern=*)
            # Complete pattern after equals sign
            cur="${cur#*=}"
            COMPREPLY=( $( compgen -W "*.txt *.log *.tmp *.bak" -- "$cur" ) )
            return 0
            ;;
        --build-dirs=*)
            # Complete build directory patterns after equals sign
            cur="${cur#*=}"
            # Split on commas if present to support multiple patterns
            if [[ $cur == *,* ]]; then
                # Get the part after the last comma
                local prefix="${cur%,*},"
                cur="${cur##*,}"
                COMPREPLY=( $( compgen -W "$build_patterns" -P "$prefix" -- "$cur" ) )
            else
                COMPREPLY=( $( compgen -W "$build_patterns" -- "$cur" ) )
            fi
            return 0
            ;;
        -*)
            # Complete options
            COMPREPLY=( $( compgen -W "$opts" -- "$cur" ) )
            return 0
            ;;
    esac

    # Default to files and directories
    _filedir
}

_unbundle_sh() {
    local cur prev opts base
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Basic options
    opts="--output -o --force -f --preview -p --version -v --help -h"

    # Handle option arguments
    case $prev in
        -o|--output)
            # Complete with directories only
            _filedir -d
            return 0
            ;;
        -p|--preview)
            # Complete with txt files only
            _filedir 'txt'
            return 0
            ;;
    esac

    # Handle options with attached arguments
    case $cur in
        --output=*)
            # Complete directory after equals sign
            cur="${cur#*=}"
            _filedir -d
            return 0
            ;;
        -*)
            # Complete options
            COMPREPLY=( $( compgen -W "$opts" -- "$cur" ) )
            return 0
            ;;
    esac

    # Default to txt files and directories
    _filedir 'txt'
}

complete -F _bundle_sh bundle.sh
complete -F _unbundle_sh unbundle.sh