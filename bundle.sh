#!/bin/bash
VERSION="1.0.0-preview"
PROGRAM_NAME=$(basename "$0")

# Enable debug mode temporarily
# set -x

show_usage() {
    echo "A bundle is a simple text file that packages multiple files together for easier distribution. Use unbundle to restore the original files from the bundle."
    echo
    echo "Usage: "
    echo "  $0 [options] <input_paths...>                 # Use default output file name (equals: -o bundle.txt)"
    echo "  $0 [options] -o <output_file> <input_paths...>"
    echo
    echo "Options:"
    echo "  -o, --output=FILE     Specify output file (default: bundle.txt)"
    echo "  -f, --force           Overwrite existing output file"
    echo "  -a, --all             Include all files (disable default exclusions)"
    echo "  -h, --help                 Show this help message"
    echo "  -v, --version         Show version information"
    echo "  --no-git-ignore       Don't respect .gitignore files"
    echo "  --include-hidden      Include hidden files and directories"
    echo "  --include-build       Include build directories (build/, .gradle/, etc.)"
    echo "  --include-binary      Include binary files"
    echo "  --include-empty-dirs  Include empty directories"
    echo "  --exclude=FILE        Exclude specific file or path (can be used multiple times)"
    echo "  --exclude-pattern=PAT Exclude files matching pattern (can be used multiple times)"
    echo "  --build-dirs=DIRS     Specify build directories to exclude (comma-separated)"
    echo
    echo "Build directory patterns:"
    echo "  Default: build/,.gradle/,.kotlin/,target/,dist/,node_modules/"
    echo "  Example: --build-dirs=out/,target/,build/"
    echo "  Use --build-dirs= (empty) to clear defaults"
    exit 1
}

show_version() {
    echo "$PROGRAM_NAME version $VERSION"
    exit 0
}

matches_exclusion_pattern() {
    local file="$1"
    local pattern
    
    # Check exact file exclusions
    for excl in "${EXCLUDE_FILES[@]}"; do
        if [ "$file" = "$excl" ] || [ "$file" = "./$excl" ]; then
            return 0
        fi
    done
    
    # Enable extended glob patterns
    shopt -s extglob nullglob

    # Check pattern exclusions
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        # Handle directory wildcards
        if [[ "$pattern" == *"**"* ]]; then
            # Convert ** to * for deeper matching
            local converted_pattern="${pattern//\*\*/*}"
            if [[ "$file" == $converted_pattern ]]; then
                return 0
            fi
        else
            # Direct pattern match
            if [[ "$file" == $pattern ]]; then
                return 0
            fi
        fi
    done
    
    return 1
}

is_ignored_by_git() {
    if [ "$USE_GIT" -eq 1 ]; then
        # Only check if we're inside a git repository
        if [ -d ".git" ] || git rev-parse --git-dir > /dev/null 2>&1; then
            git check-ignore -q "$1"
            return $?
        fi
    fi
    return 1
}

is_binary() {
    local file="$1"
    local size
    local mime_type

    # Get file size
    size=$(wc -c < "$file")

    # Empty files or files with just a newline are not binary
    if [ "$size" -eq 0 ] || [ "$size" -eq 1 ]; then
        return 1  # Not binary
    fi

    # Check if file is binary
    mime_type=$(file -bL --mime "$file")
    echo "$mime_type" | grep -q "charset=binary" && ! echo "$mime_type" | grep -q "^text/"
}

get_relative_path() {
    python3 -c "
import os
print(os.path.relpath('$1', '$2'))
" 2>/dev/null || echo "$1"
}

get_file_metadata() {
    local file="$1"
    local stat_format

    # Check if we're on BSD (macOS) or GNU stat
    if stat --version 2>/dev/null | grep -q GNU; then
        # GNU stat
        stat_format="%a:%u:%g:%Y"  # mode:uid:gid:mtime
        stat -c "$stat_format" "$file"
    else
        # BSD stat (macOS)
        stat -f "%Lp:%u:%g:%m" "$file"
    fi
}

process_directory() {
    local dir="$1"
    local base_dir="$2"
    local rel_path
    local metadata

    # Get relative path
    rel_path=$(get_relative_path "$dir" "$base_dir")

    # Skip if directory matches exclusion patterns
    if matches_exclusion_pattern "$rel_path"; then
        echo "Skipping (excluded): $rel_path/"
        return
    fi

    # Apply exclusion rules for directories
    if [ "$INCLUDE_ALL" != "true" ]; then
        # Skip hidden directories unless explicitly included
        if [ "$INCLUDE_HIDDEN" != "true" ] && [[ "$rel_path" =~ /\. || "$rel_path" =~ ^\. ]]; then
            echo "Skipping (hidden): $rel_path/"
            return
        fi

        # Skip build directories unless explicitly included
        if [ "$INCLUDE_BUILD" != "true" ] && is_build_dir "$rel_path"; then
            echo "Skipping (build): $rel_path/"
            return
        fi

        # Check git ignore rules if enabled
        if [ "$USE_GIT" -eq 1 ] && [ "$NO_GIT_IGNORE" != "true" ]; then
            if is_ignored_by_git "$rel_path"; then
                echo "Skipping (gitignored): $rel_path/"
                return
            fi
        fi
    fi

    # Check if the directory is empty
    if [ -z "$(find "$dir" -mindepth 1 -print -quit)" ]; then
        # Get directory metadata
        metadata=$(get_file_metadata "$dir")

        # Write directory marker to bundle
        echo "###START_DIR:$rel_path###" >> "$OUTPUT_FILE"
        echo "###METADATA:$metadata###" >> "$OUTPUT_FILE"
        echo "###END_DIR:$rel_path###" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"

        echo "Processed directory: $rel_path/"
        ((PROCESSED_DIRS++))
    fi
}

is_build_dir() {
    local path="$1"
    local pattern

    # Check against build directory patterns
    for pattern in "${BUILD_DIRS[@]}"; do
        if [[ "$path" =~ /${pattern%/}/ ]]; then
            return 0
        fi
    done

    return 1
}

process_file() {
    local file="$1"
    local base_dir="$2"
    local rel_path
    local metadata
    local file_size

    # Skip if file doesn't exist or isn't readable
    [ ! -f "$file" ] && return
    [ ! -r "$file" ] && return

    # Get relative path
    rel_path=$(get_relative_path "$file" "$base_dir")

    # Check custom exclusions first
    if matches_exclusion_pattern "$rel_path"; then
        echo "Skipping (excluded): $rel_path"
        return
    fi

    # Apply exclusion rules
    if [ "$INCLUDE_ALL" != "true" ]; then
        # Skip hidden files/paths unless explicitly included
        if [ "$INCLUDE_HIDDEN" != "true" ] && [[ "$rel_path" =~ /\. || "$rel_path" =~ ^\. ]]; then
            echo "Skipping (hidden): $rel_path"
            return
        fi

        # Skip build directories unless explicitly included
        if [ "$INCLUDE_BUILD" != "true" ] && is_build_dir "$rel_path"; then
            echo "Skipping (build): $rel_path"
            return
        fi
        
        # Skip binary files unless explicitly included
        if [ "$INCLUDE_BINARY" != "true" ] && is_binary "$file"; then
            echo "Skipping (binary): $rel_path"
            return
        fi
        
        # Check git ignore rules if enabled
        if [ "$USE_GIT" -eq 1 ] && [ "$NO_GIT_IGNORE" != "true" ]; then
            if is_ignored_by_git "$rel_path"; then
                echo "Skipping (gitignored): $rel_path"
                return
            fi
        fi
    fi
    
    # Get file metadata
    metadata=$(get_file_metadata "$file")
    file_size=$(wc -c < "$file" | tr -d ' ')

    # Write file metadata and content to bundle
    echo "###START_FILE:$rel_path###" >> "$OUTPUT_FILE"
    echo "###METADATA:$metadata###" >> "$OUTPUT_FILE"
    echo "###SIZE:$file_size###" >> "$OUTPUT_FILE"
    cat "$file" >> "$OUTPUT_FILE"
    echo "###END_FILE:$rel_path###" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    echo "Processed: $rel_path"
    ((PROCESSED_FILES++))
    ((PROCESSED_BYTES += file_size))
}

# Initialize variables
OUTPUT_FILE="bundle.txt"
FORCE="false"
INCLUDE_ALL="false"
INCLUDE_HIDDEN="false"
INCLUDE_BUILD="false"
INCLUDE_BINARY="false"
INCLUDE_EMPTY_DIRS="false"
NO_GIT_IGNORE="false"
USE_GIT=0
PROCESSED_FILES=0
PROCESSED_DIRS=0
PROCESSED_BYTES=0
declare -a EXCLUDE_FILES
declare -a EXCLUDE_PATTERNS
declare -a INPUTS
# Default build directory patterns
declare -a BUILD_DIRS=(
    "build/"
    ".gradle/"
    ".kotlin/"
    "target/"
    "dist/"
    "node_modules/"
    "bin/"
    "obj/"
    "__pycache__/"
    ".pytest_cache/"
    "venv/"
    ".venv/"
    "out/"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -o=*|--output=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        -f|--force)
            FORCE="true"
            shift
            ;;
        -a|--all)
            INCLUDE_ALL="true"
            shift
            ;;
        --no-git-ignore)
            NO_GIT_IGNORE="true"
            shift
            ;;
        --include-hidden)
            INCLUDE_HIDDEN="true"
            shift
            ;;
        --include-build)
            INCLUDE_BUILD="true"
            shift
            ;;
        --include-binary)
            INCLUDE_BINARY="true"
            shift
            ;;
        --include-empty-dirs)
            INCLUDE_EMPTY_DIRS="true"
            shift
            ;;
        --exclude=*)
            EXCLUDE_FILES+=("${1#*=}")
            shift
            ;;
        --exclude-pattern=*)
            EXCLUDE_PATTERNS+=("${1#*=}")
            shift
            ;;
        --build-dirs=*)
            # Clear default patterns if user provides their own
            BUILD_DIRS=()
            # Split the comma-separated list and ensure trailing slashes
            IFS=',' read -r -a new_dirs <<< "${1#*=}"
            for dir in "${new_dirs[@]}"; do
                if [ -n "$dir" ]; then
                    BUILD_DIRS+=("${dir%/}/")
                fi
            done
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        -v|--version)
            show_version
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            ;;
        *)
            INPUTS+=("$1")
            shift
            ;;
    esac
done

# Check if we have any inputs
if [ ${#INPUTS[@]} -eq 0 ]; then
    echo "Error: No input paths specified"
    show_usage
fi

# Check if output file exists
if [ -f "$OUTPUT_FILE" ] && [ "$FORCE" != "true" ]; then
    echo "Error: Output file '$OUTPUT_FILE' already exists"
    echo "Use -f or --force to overwrite"
    exit 1
fi

# Check if git is available and we're in a git repository
if command -v git >/dev/null 2>&1; then
    if [ -d ".git" ] || git rev-parse --git-dir > /dev/null 2>&1; then
        USE_GIT=1
    else
        echo "Note: Not a git repository, .gitignore rules will not be applied."
    fi
else
    echo "Note: git is not installed, .gitignore rules will not be applied."
fi

# Create or clear the output file
:> "$OUTPUT_FILE"

# Write bundle header
ROOT_DIR_NAME=$(basename "$(cd "${INPUTS[0]}" && pwd -P)")
echo "###BUNDLE_ROOT:${ROOT_DIR_NAME}###" >> "$OUTPUT_FILE"
echo "###BUNDLE_DATE:$(date -u +"%Y-%m-%dT%H:%M:%SZ")###" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Process all inputs
for input in "${INPUTS[@]}"; do
    if [ -f "$input" ]; then
        # Single file
        process_file "$input" "$(dirname "$input")"
    elif [ -d "$input" ]; then
        # First process all files
        while IFS= read -r -d '' file; do
            process_file "$file" "$input"
        done < <(find "$input" -type f -print0)

        # Then process directories if requested
        if [ "$INCLUDE_EMPTY_DIRS" = "true" ]; then
            while IFS= read -r -d '' dir; do
                # Only process directories that don't contain any files
                if [ -z "$(find "$dir" -type f -print0 2>/dev/null)" ]; then
                    process_directory "$dir" "$input"
                fi
            done < <(find "$input" -type d -print0)
        fi
    else
        echo "Warning: Input '$input' not found, skipping"
    fi
done

# Print summary
echo "----------------------------------------"
echo "Bundle complete:"
echo "Files processed: $PROCESSED_FILES"
if [ "$INCLUDE_EMPTY_DIRS" = "true" ]; then
    echo "Empty directories: $PROCESSED_DIRS"
fi
if ((PROCESSED_BYTES >= 1048576)); then
    echo "Total size: $(echo "scale=1; $PROCESSED_BYTES/1048576" | bc)M"
elif ((PROCESSED_BYTES >= 1024)); then
    echo "Total size: $(echo "scale=1; $PROCESSED_BYTES/1024" | bc)K"
else
    echo "Total size: ${PROCESSED_BYTES}B"
fi
echo "Output written to: $OUTPUT_FILE"