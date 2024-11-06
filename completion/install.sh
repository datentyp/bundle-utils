#!/usr/bin/env sh

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Detect shell
detect_shell() {
    # First try to detect from version variables as they're most reliable
    # when actually running in that shell
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
        return
    fi

    if [ -n "$BASH_VERSION" ]; then
        echo "bash"
        return
    fi

    # Try to detect from process info
    case "$(ps -p $$ -o comm=)" in
        *zsh*)
            echo "zsh"
            ;;
        *bash*)
            echo "bash"
            ;;
        *)
            # Finally check $SHELL, but only if we couldn't detect otherwise
            case "$SHELL" in
                */zsh)
                    echo "zsh"
                    ;;
                */bash)
                    echo "bash"
                    ;;
                *)
                    echo "unknown"
                    ;;
            esac
            ;;
    esac
}

# Install bash completion
install_bash_completion() {
    local completion_dir
    local source_file="bash-completion.sh"
    local target_file="bundle-utils"

    # Determine completion directory
    if [ -d "$HOME/.local/share/bash-completion/completions" ]; then
        completion_dir="$HOME/.local/share/bash-completion/completions"
    elif [ -d "/etc/bash_completion.d" ]; then
        completion_dir="/etc/bash_completion.d"
        if [ ! -w "$completion_dir" ]; then
            echo -e "${RED}Error: No write permission for system completion directory.${NC}"
            echo "Please run with sudo or install to user directory."
            return 1
        fi
    else
        completion_dir="$HOME/.bash_completion.d"
        mkdir -p "$completion_dir"
    fi

    # Install completion script
    cp "$source_file" "$completion_dir/$target_file"
    chmod 644 "$completion_dir/$target_file"

    # Add to .bashrc if needed
    local bashrc="$HOME/.bashrc"
    if ! grep -q "bash-completion" "$bashrc"; then
        cat >> "$bashrc" << EOL

# Load bash completions
if [ -d "$completion_dir" ]; then
    for completion in "$completion_dir"/*; do
        if [ -r "\$completion" ]; then
            . "\$completion"
        fi
    done
fi
EOL
    fi

    echo -e "${GREEN}Installed bash completion to $completion_dir${NC}"
    echo "Please restart your shell or run: source ~/.bashrc"
}

# Install zsh completion
install_zsh_completion() {
    local completion_dir
    local source_file="zsh-completion.txt"
    local target_file="_bundle-utils"

    # Determine completion directory
    if [ -d "$HOME/.zsh/completions" ]; then
        completion_dir="$HOME/.zsh/completions"
    else
        completion_dir="$HOME/.zsh/completions"
        mkdir -p "$completion_dir"
    fi

    # Install completion script
    cp "$source_file" "$completion_dir/$target_file"
    chmod 644 "$completion_dir/$target_file"

    # Add to .zshrc if needed
    local zshrc="$HOME/.zshrc"
    if ! grep -q "fpath=.*${completion_dir}" "$zshrc"; then
        cat >> "$zshrc" << EOL

# Load custom completions
fpath=($completion_dir \$fpath)
autoload -U compinit
compinit
EOL
    fi

    echo -e "${GREEN}Installed zsh completion to $completion_dir${NC}"
    echo "Please restart your shell or run: source ~/.zshrc"
}

# Test completion files exist
check_source_files() {
    local missing=0

    if [ ! -f "bash-completion.sh" ]; then
        echo -e "${RED}Error: bash-completion.sh not found${NC}"
        missing=1
    fi

    if [ ! -f "zsh-completion.txt" ]; then
        echo -e "${RED}Error: zsh-completion.txt not found${NC}"
        missing=1
    fi

    return $missing
}

# Main installation
main() {
    local shell

    echo "Checking completion files..."
    if ! check_source_files; then
        echo -e "${RED}Error: Required completion files are missing${NC}"
        exit 1
    fi

    echo "Detecting shell..."
    shell=$(detect_shell)
    echo "Detected shell: $shell"

    case "$shell" in
        bash)
            echo "Installing bash completions..."
            install_bash_completion
            ;;
        zsh)
            echo "Installing zsh completions..."
            install_zsh_completion
            ;;
        *)
            echo -e "${RED}Error: Unsupported shell. Please use bash or zsh.${NC}"
            exit 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Completion installation successful!${NC}"
        echo "New options like --build-dirs will be available after restarting your shell"
    else
        echo -e "${RED}Completion installation failed!${NC}"
        exit 1
    fi
}

# Run installation
main "$@"