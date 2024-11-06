#!/bin/bash
VERSION="1.0.0-preview"
PROGRAM_NAME=$(basename "$0")

# Show usage if arguments are missing or invalid
show_usage() {
    echo "A bundle is a simple text file that packages multiple files together for easier distribution. Use unbundle to restore the original files from the bundle."
    echo
    echo "Usage: "
    echo "  $0 [options] [input_bundle] [output_parent_directory]"
    echo
    echo "Arguments:"
    echo "  input_bundle               Bundle file to unbundle (default: bundle.txt)"
    echo "  output_parent_directory    Where to unbundle (default: current directory)"
    echo
    echo "Options:"
    echo "  -p, --preview              Show contents of the bundle (dry run without unbundling)"
    echo "  -f, --force                Overwrite existing directory"
    echo "  -o, --output=DIR           Unbundle to specified directory instead of original name"
    echo "  -h, --help                 Show this help message"
    echo "  -v, --version              Show version information"
    echo
    echo "Examples:"
    echo "  $0                         # Unbundle bundle.txt in current directory"
    echo "  $0 release.txt             # Unbundle release.txt in current directory"
    echo "  $0 bundle.txt parent_dir   # Unbundle to parent_dir/original_name"
    echo "  $0 -o custom_dir           # Unbundle bundle.txt to custom_dir"
    echo "  $0 -f bundle.txt           # Force overwrite if directory exists"
    echo "  $0 -p                      # Preview contents of bundle.txt"
    echo "  $0 -p other.txt            # Preview contents of other.txt"
    exit 1
}

show_version() {
    echo "$PROGRAM_NAME version $VERSION"
    exit 0
}

# Function to format timestamp
format_timestamp() {
    local timestamp="$1"
    if date --version 2>/dev/null | grep -q GNU; then
        # GNU date
        date -d "@$timestamp" "+%Y-%m-%d %H:%M"
    else
        # BSD date (macOS)
        date -r "$timestamp" "+%Y-%m-%d %H:%M"
    fi
}

# Function to format permissions - With special bits support
format_permissions() {
    local mode="$1"
    local symbolic

    # Convert mode to octal if it's not already
    mode=$(printf '%d' "0$mode")

    # Convert numeric mode to symbolic (rwxrwxrwx)
    symbolic=""
    # Owner (4 = 100, 2 = 010, 1 = 001)
    symbolic+="$( (( (mode & 0400) == 0400 )) && echo "r" || echo "-")"
    symbolic+="$( (( (mode & 0200) == 0200 )) && echo "w" || echo "-")"
    # Execute/SetUID - check both execute and setuid bits
    if (( (mode & 0100) == 0100 )); then
        symbolic+="$( (( (mode & 04000) == 04000 )) && echo "s" || echo "x")"
    else
        symbolic+="$( (( (mode & 04000) == 04000 )) && echo "S" || echo "-")"
    fi

    # Group
    symbolic+="$( (( (mode & 040) == 040 )) && echo "r" || echo "-")"
    symbolic+="$( (( (mode & 020) == 020 )) && echo "w" || echo "-")"
    # Execute/SetGID - check both execute and setgid bits
    if (( (mode & 010) == 010 )); then
        symbolic+="$( (( (mode & 02000) == 02000 )) && echo "s" || echo "x")"
    else
        symbolic+="$( (( (mode & 02000) == 02000 )) && echo "S" || echo "-")"
    fi

    # Others
    symbolic+="$( (( (mode & 04) == 04 )) && echo "r" || echo "-")"
    symbolic+="$( (( (mode & 02) == 02 )) && echo "w" || echo "-")"
    # Execute/Sticky - check both execute and sticky bits
    if (( (mode & 01) == 01 )); then
        symbolic+="$( (( (mode & 01000) == 01000 )) && echo "t" || echo "x")"
    else
        symbolic+="$( (( (mode & 01000) == 01000 )) && echo "T" || echo "-")"
    fi

    echo "$symbolic"
}

# Format file size
format_size() {
    local size="$1"
    if [ "$size" -ge 1048576 ]; then
        printf "%4.1fM" "$(echo "scale=1; $size/1048576" | bc)"
    elif [ "$size" -ge 1024 ]; then
        printf "%4.1fK" "$(echo "scale=1; $size/1024" | bc)"
    else
        printf "%4dB" "$size"
    fi
}

# Preview function
preview_bundle() {
    local input_bundle="$1"
    local total_files=0
    local total_dirs=0
    local total_size=0
    local root_dir=""
    local bundle_date=""
    local temp_content

    echo "Preview of bundle: $input_bundle" >&2
    echo "----------------------------------------"

    # First read bundle header
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ $line =~ ^###BUNDLE_ROOT:(.*)###$ ]]; then
            root_dir="${BASH_REMATCH[1]}"
            echo "Root directory: $root_dir"
        elif [[ $line =~ ^###BUNDLE_DATE:(.*)###$ ]]; then
            bundle_date="${BASH_REMATCH[1]}"
            echo "Bundle date: $bundle_date"
        elif [[ $line =~ ^###START_FILE: || $line =~ ^###START_DIR: ]]; then
            break
        fi
    done < "$input_bundle"

    echo
    printf "%-10s %-8s %-12s %s\n" "PERMS" "SIZE" "MODIFIED" "PATH"
    echo "------------------------------------------------------------------------"

    # Use awk for robust content processing
    temp_content=$(mktemp)

    gawk -v temp="$temp_content" '
    BEGIN { in_file = 0; total_files = 0; total_dirs = 0; total_size = 0 }

    /^###START_(FILE|DIR):/ {
        is_dir = ($0 ~ /^###START_DIR:/)
        path = substr($0, is_dir ? 14 : 15)
        sub(/###$/, "", path)
        if (is_dir) { path = path "/" }  # Add trailing slash for directories

        # Read metadata line
        if ((getline metadata_line) > 0) {
            if (match(metadata_line, /^###METADATA:([^#]+)###$/, matches)) {
                meta_part = matches[1]
                split(meta_part, meta, ":")

                if (length(meta) == 4) {
                    mode = meta[1]
                    uid = meta[2]
                    gid = meta[3]
                    mtime = meta[4]

                    if (!is_dir) {
                        # Read size line for files
                    if ((getline size_line) > 0) {
                        if (match(size_line, /^###SIZE:([0-9]+)###$/, matches)) {
                            size = matches[1]
                                printf "%s:%s:%s:%s:%s:%s:%d\n", path, mode, uid, gid, mtime, size, is_dir >> temp
                            total_files++
                            total_size += size
                        }
                    }
                } else {
                        # Directories have no size
                        printf "%s:%s:%s:%s:%s:0:%d\n", path, mode, uid, gid, mtime, is_dir >> temp
                        total_dirs++
                    }
                }
            }
        }
    }

    END {
        printf "TOTAL:%d:%d:%d\n", total_files, total_dirs, total_size >> temp
    }
    ' "$input_bundle"

    # Process the temporary file to display information
    while IFS=: read -r path mode uid gid mtime size is_dir || [ -n "$path" ]; do
        if [ "$path" = "TOTAL" ]; then
            total_files=$mode   # In TOTAL line, mode field contains total_files
            total_dirs=$uid     # In TOTAL line, uid field contains total_dirs
            total_size=$gid     # In TOTAL line, gid field contains total_size
            continue
        fi
        perms=$(format_permissions "$mode")
        if [ "$is_dir" = "1" ]; then
            printf "%-10s %-8s %-12s %s\n" "$perms" "dir" "$(format_timestamp "$mtime")" "$path"
        else
            printf "%-10s %-8s %-12s %s\n" "$perms" "$(format_size "$size")" "$(format_timestamp "$mtime")" "$path"
        fi
    done < "$temp_content"

    rm -f "$temp_content"

    echo "------------------------------------------------------------------------"
    echo "Total files: $total_files"
    echo "Total directories: $total_dirs"
    echo "Total size: $(format_size "$total_size")"
    if [ -n "$root_dir" ]; then
        echo "Will be unbundled to directory: $root_dir"
    fi
}

# Unbundle files and directories function
unbundle_files() {
    local input_bundle="$1"
    local output_dir="$2"

    # Print header
    printf "%-10s %-8s %-12s %s\n" "PERMS" "SIZE" "MODIFIED" "PATH"
    echo "------------------------------------------------------------------------"

    gawk -v output_dir="$output_dir" '
    BEGIN {
        in_content = 0
        total_files = 0
        total_dirs = 0
        total_bytes = 0
    }

    function dirname(path) {
        gsub(/\/[^\/]*$/, "", path)
        return (path == "") ? "." : path
    }

    function ensure_dir(path) {
        cmd = sprintf("mkdir -p \"%s\"", path)
        if (system(cmd) != 0) {
            return 1
        }
        cmd = sprintf("chmod 755 \"%s\"", path)
        if (system(cmd) != 0) {
            return 1
        }
        return 0
    }

    function prepare_file(path, dir) {
        # Create parent directory with full permissions temporarily
        ensure_dir(dir)

        # Create file with full write permissions initially
        cmd = sprintf("touch \"%s\" && chmod 0666 \"%s\"", path, path)
        if (system(cmd) != 0) {
            return 1
        }

        return 0
    }

    function apply_metadata(path, mode, uid, gid, mtime) {
        # Convert mode to proper octal value
        mode = sprintf("%04o", strtonum("0" mode))

        # Set permissions with explicit octal notation
        cmd = sprintf("chmod 0%s \"%s\"", mode, path)
        if (system(cmd) != 0) {
            return 1
        }

        # Set ownership if root
        if (system("test $(id -u) -eq 0") == 0) {
            system(sprintf("chown %s:%s \"%s\"", uid, gid, path))
        }

        # Set timestamp
        cmd = sprintf("date -r %s +%%Y%%m%%d%%H%%M.%%S", mtime)
        cmd | getline timestamp
        close(cmd)
        if (system(sprintf("touch -t %s \"%s\"", timestamp, path)) != 0) {
            return 1
        }

        return 0
    }

    /^###START_(FILE|DIR):/ {
        is_dir = ($0 ~ /^###START_DIR:/)
        path = substr($0, is_dir ? 14 : 15)
        sub(/###$/, "", path)
        target_path = output_dir "/" path
        target_dir = is_dir ? target_path : dirname(target_path)

        # Read metadata line
        if ((getline metadata_line) > 0) {
            if (match(metadata_line, /^###METADATA:([^#]+)###$/, matches)) {
                meta_part = matches[1]
                split(meta_part, meta, ":")
                mode = meta[1]
                uid = meta[2]
                gid = meta[3]
                mtime = meta[4]

                if (is_dir) {
                    # Create and setup directory
                    ensure_dir(target_path)
                    if (apply_metadata(target_path, mode, uid, gid, mtime) == 0) {
                        printf "PROCESSED_DIR:%s:%s:%s\n", mode, mtime, path
                        total_dirs++
                    }
                } else {
                    # Handle file content
                    if ((getline size_line) > 0) {
                        if (match(size_line, /^###SIZE:([0-9]+)###$/, matches)) {
                            size = matches[1]
                            if (prepare_file(target_path, target_dir) == 0) {
                                in_content = 1
                                current_target = target_path
                                current_mode = mode
                                current_uid = uid
                                current_gid = gid
                                current_mtime = mtime
                                current_path = path
                            }
                        }
                    }
                }
            }
        }
        next
    }

    /^###END_(FILE|DIR):/ {
        if (in_content) {
            close(current_target)

            # Verify file was written successfully
            if (system(sprintf("test -s \"%s\"", current_target)) == 0) {
                # Apply metadata and check result
                if (apply_metadata(current_target, current_mode, current_uid, current_gid, current_mtime) == 0) {
                    # Get final size
                    cmd = sprintf("wc -c < \"%s\"", current_target)
                    cmd | getline file_size
                    close(cmd)
                    file_size = file_size + 0  # Force numeric conversion
                    total_bytes += file_size

                    printf "PROCESSED_FILE:%s:%s:%s:%s\n", current_mode, file_size, current_mtime, current_path
                    total_files++
                }
            }
            in_content = 0
        }
        next
    }

    in_content {
        print > current_target
    }

    END {
        if (in_content) {
            close(current_target)
        }
        printf "TOTAL:%d:%d:%d\n", total_files, total_dirs, total_bytes
    }
    ' "$input_bundle" | post_process_summary
}

# Post-process the extraction output
post_process_summary() {
    export -f format_permissions format_size format_timestamp

    gawk '
    BEGIN {
        format_perms_cmd = "bash -c '\''format_permissions %s'\''"
        format_size_cmd = "bash -c '\''format_size %s'\''"
        format_time_cmd = "bash -c '\''format_timestamp %s'\''"
    }

    /^PROCESSED_FILE:/ {
        split($0, parts, ":")
        mode = parts[2]
        size = parts[3]
        mtime = parts[4]
        filename = parts[5]

        # Get formatted values
        cmd = sprintf(format_perms_cmd, mode)
        cmd | getline perms
        close(cmd)

        cmd = sprintf(format_size_cmd, size)
        cmd | getline formatted_size
        close(cmd)

        cmd = sprintf(format_time_cmd, mtime)
        cmd | getline formatted_time
        close(cmd)

        printf "%-10s %-8s %-12s %s\n", perms, formatted_size, formatted_time, filename
        next
    }

    /^PROCESSED_DIR:/ {
        split($0, parts, ":")
        mode = parts[2]
        mtime = parts[3]
        dirname = parts[4]

        # Get formatted values
        cmd = sprintf(format_perms_cmd, mode)
        cmd | getline perms
        close(cmd)

        cmd = sprintf(format_time_cmd, mtime)
        cmd | getline formatted_time
        close(cmd)

        printf "%-10s %-8s %-12s %s/\n", perms, "dir", formatted_time, dirname
        next
    }

    /^TOTAL:/ {
        split($0, parts, ":")
        files = parts[2]
        dirs = parts[3]
        bytes = parts[4]

        print "------------------------------------------------------------------------"
        print "Files extracted: " files
        print "Directories created: " dirs

        cmd = sprintf(format_size_cmd, bytes)
        cmd | getline formatted_size
        close(cmd)
        print "Total size: " formatted_size
    }

    {print}
    '
}

# Parse arguments
FORCE=0
OUTPUT_DIR=""
PREVIEW=0
INPUT_BUNDLE="bundle.txt"  # Set default input file
PARENT_DIR="."            # Set default parent directory
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--preview)
            PREVIEW=1
            shift
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -o=*|--output=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        -v|--version)
            show_version
            ;;
        -*|--*)
            echo "Unknown option $1"
            show_usage
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Process positional arguments
case ${#POSITIONAL_ARGS[@]} in
    0)  # Use defaults for both input and output
        ;;
    1)  # First arg could be either input file or output directory
        if [ -f "${POSITIONAL_ARGS[0]}" ]; then
            INPUT_BUNDLE="${POSITIONAL_ARGS[0]}"
        else
            PARENT_DIR="${POSITIONAL_ARGS[0]}"
        fi
        ;;
    2)  # Both input file and output directory specified
        INPUT_BUNDLE="${POSITIONAL_ARGS[0]}"
        PARENT_DIR="${POSITIONAL_ARGS[1]}"
        ;;
    *)
        echo "Error: Too many arguments"
        show_usage
        ;;
esac

# Handle preview mode
if [ $PREVIEW -eq 1 ]; then
    if [ ! -f "$INPUT_BUNDLE" ]; then
        echo "Error: Bundle file '$INPUT_BUNDLE' does not exist"
        exit 1
    fi
    preview_bundle "$INPUT_BUNDLE"
    exit 0
fi

# Check if input bundle exists
if [ ! -f "$INPUT_BUNDLE" ]; then
    echo "Error: Bundle file '$INPUT_BUNDLE' does not exist"
    exit 1
fi

# Read the root directory name from the bundle
ROOT_DIR=""
while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ ^###BUNDLE_ROOT:(.*)###$ ]]; then
        ROOT_DIR="${BASH_REMATCH[1]}"
        break
    fi
done < "$INPUT_BUNDLE"

if [ -z "$ROOT_DIR" ]; then
    echo "Error: Bundle file does not contain root directory information"
    exit 1
fi

# Determine final output directory
if [ -n "$OUTPUT_DIR" ]; then
    FINAL_OUTPUT_DIR="$OUTPUT_DIR"
else
    FINAL_OUTPUT_DIR="$PARENT_DIR/$ROOT_DIR"
fi

# Check if directory exists and handle force option
if [ -d "$FINAL_OUTPUT_DIR" ]; then
    if [ $FORCE -eq 1 ]; then
        echo "Warning: Overwriting existing directory: $FINAL_OUTPUT_DIR"
    else
        echo "Error: Directory already exists: $FINAL_OUTPUT_DIR"
        echo "Use -f or --force to overwrite"
        exit 1
    fi
fi

# Create output directory
mkdir -p "$FINAL_OUTPUT_DIR"

# Convert to absolute path
cd "$FINAL_OUTPUT_DIR" || exit 1
FINAL_OUTPUT_DIR="$(pwd)"
cd - > /dev/null || exit 1

printf "Extracting files to: $FINAL_OUTPUT_DIR\n\n"
unbundle_files "$INPUT_BUNDLE" "$FINAL_OUTPUT_DIR" | post_process_summary
