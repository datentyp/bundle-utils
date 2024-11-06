# Bundle Utils

*__Putting it all together in a single file.__*

Scripts to bundle directory contents into a distribution package and to unbundle (extract) them back, with support for various
in- and exclusion options.

It's basically an enhanced version of:

```shell
for i in *; do 
  if [[ -f "$i" ]]; then 
      echo "=== This is file: $i ===" >> bundle.txt; 
      cat $i >> bundle.txt;
  fi; 
done
```

that is obviously not meant to replace proper tools like `tar`, but it can be useful for quick distribution of small
projects or scripts.



Motivation:

> Some web services restrict the number of files to be uploaded on their web interface but are willing to accept
> larger files. By bundling multiple files into a single, well-structured package, you can work around these limits while
> keeping the contents easily accessible to both humans and *automated systems*.



## Features

- Bundle multiple files and directories into a single file
- Smart file exclusions (binary, build directories, Git-ignored files)
- Customizable exclusion patterns
- Preview bundle contents
- Preserve directory structure
- Automatic handling of default filenames
- Force overwrite protection



## Installation

### Install

1. Clone the repository:

```bash
git clone https://github.com/datentyp/bundle-utils.git
cd bundle-utils
```

2. Make the scripts executable:

```bash
chmod +x bundle.sh unbundle.sh
```

3. (Optional) Add to your PATH for system-wide access:

```bash
export PATH="$PATH:/path/to/bundle-utils"
```


### Requirements

The scripts require the following tools to be installed:

#### Core Dependencies

- Bash 4.0 or later
- GNU awk (gawk) 4.0 or later
    - We use GAWK-specific features for better text processing
    - Standard awk or mawk are not sufficient
- GNU date (gdate on macOS) or BSD date
- file (for detecting binary files)
- Git (optional, for .gitignore support)
- Python 3 (for path handling)
- GNU core utilities (for file operations)

#### Installation on different systems

##### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install gawk git python3 coreutils
```

##### macOS

```bash
# Using Homebrew
brew install gawk coreutils git python3

# Note: On macOS, GNU utilities are prefixed with 'g'
# The scripts handle this automatically
```

##### Other Linux distributions

```bash
# For RPM-based systems (Fedora, RHEL, CentOS)
sudo dnf install gawk git python3 coreutils

# For Arch Linux
sudo pacman -S gawk git python3 coreutils
```

#### Verifying GAWK Installation

```bash
# Check if gawk is installed and get its version
gawk --version

# Should output something like:
# GNU Awk 5.0.1, API: 3.0 (GNU MPFR 4.1.0, GNU MP 6.2.1)
```

### Shell Completion Scripts

1. Install them.

```shell
cd completion
chmod +x install.sh

# Depending on the shell you are using run either
zsh ./install.sh
# or
bash ./install.sh
```

2. Restart your shell or source your RC file.

```shell
# For bash
source ~/.bashrc

# For zsh
source ~/.zshrc
```

```bash
# Try typing and pressing TAB:
bundle.sh --[TAB]              # Shows all options
bundle.sh --exclude=[TAB]      # Shows files
bundle.sh --exclude-pattern=[TAB]  # Shows pattern suggestions

unbundle.sh -[TAB]             # Shows all options
unbundle.sh [TAB]              # Shows .txt files
unbundle.sh somefile.txt [TAB] # Shows directories
```



## Usage

### Bundling Files

Basic usage:

```bash
./bundle.sh <input_paths...>                # Creates bundle.txt
./bundle.sh -o output.txt <input_paths...>  # Specify output file
```

Options:

```
  -o, --output=FILE     Specify output file (default: bundle.txt)
  -f, --force           Overwrite existing output file
  -a, --all             Include all files (disable default exclusions)
  -v, --version         Show version information
  --no-git-ignore       Don't respect .gitignore files
  --include-hidden      Include hidden files and directories
  --include-build       Include build directories (build/, .gradle/, etc.)
  --include-binary      Include binary files
  --include-empty-dirs  Include empty directories
  --exclude=FILE        Exclude specific file or path (can be used multiple times)
  --exclude-pattern=PAT Exclude files matching pattern (can be used multiple times)
  --build-dirs=DIRS     Specify build directories to exclude (comma-separated)"
```

Examples:

```bash
# Bundle a specific directory
./bundle.sh src/

# Bundle multiple inputs
./bundle.sh src/ lib/ tests/

# Bundle with custom output name
./bundle.sh -o release.txt src/

# Bundle with exclusions
./bundle.sh --exclude=secrets.txt --exclude-pattern='*.log' src/



# Bundle everything including normally excluded files
./bundle.sh -a project/
```

#### Default Exclusions

By default, the following are excluded:

- Hidden files and directories (starting with .)
- Build directories (build/, .gradle/, .kotlin/ etc.)
- Binary files
- Files matched by .gitignore rules (when in a Git repository)

Use the corresponding --include switches to include them nonetheless.

##### Custom Exclusions

* Use `--exclude=buildX` to only match a file/directory named exactly "buildX"
* Use `--exclude=buildX/` to match only direct (first level) buildX directories
* Use `--exclude-pattern=*/buildX/*` or `--exclude-pattern="**/buildX/**"`: to match any files/directories under any buildX directory at any level

##### Excluded Build Directories

By default, the following build directories are ignored:

```text
* __pycache__/, .pytest_cache/, venv/, .venv/
* bin/, obj/
* node_modules/
* target/, .gradle/, .kotlin/
* build/, dist/, out/
```

The build directory exclusion behavior can be extented or deactivated with the `--build-dirs` option.

Examples:

```bash
# Specify custom build directories
bundle.sh --build-dirs=out/,target/,build/ src/

# Clear default patterns and specify your own
bundle.sh --build-dirs=cmake-build/,bazel-out/ src/

# Clear all build directory patterns
bundle.sh --build-dirs= src/
```

### Unbundling Files

Basic usage:

```bash
./unbundle.sh                    # Extracts bundle.txt
./unbundle.sh input.txt          # Extracts specific bundle
./unbundle.sh -o custom_dir      # Extracts to specific directory
```

Options:

```
  -p, --preview              Show contents of the bundle (dry run without unbundling)
  -f, --force                Overwrite existing directory
  -o, --output=DIR           Unbundle to specified directory instead of original name
  -h, --help                 Show this help message
  -v, --version              Show version information
```

Examples:

```bash
# Preview bundle contents
./unbundle.sh -p

# Extract to specific directory
./unbundle.sh -o /path/to/extract

# Force overwrite existing directory
./unbundle.sh -f

# Extract specific bundle file
./unbundle.sh release.txt
```

### Previewing Bundle Contents

```text
# Preview
$ ./unbundle.sh -p bundle.txt
Preview of bundle: bundle.txt
----------------------------------------
Root directory: project
Bundle date: 2024-10-29T14:04:28Z

PERMS     SIZE     MODIFIED         FILE
------------------------------------------------------------------------
rwxr-xr-x 4.1K     2024-10-29 14:04 bin/script.sh
rw-r--r-- 2.2K     2024-10-29 14:05 data/input.txt
------------------------------------------------------------------------
Total files: 2
Total size: 6.3K

# Extraction
$ ./unbundle.sh bundle.txt
Extracting files to: /tmp/project
Extracted [rwxr-xr-x] 4.1K: bin/script.sh
Extracted [rw-r--r--] 2.2K: data/input.txt
----------------------------------------
Extraction complete:
Files extracted: 2
Total size: 6.3K
```

## Bundle File Format Specification

### Overview
A bundle is a plain text file that packages multiple files and directories together for easier distribution. The format uses simple markers and metadata to preserve file attributes and structure.

### File Structure
A bundle consists of:
1. A header section containing bundle metadata
2. Zero or more file/directory entries
3. Each entry contains metadata and content sections

#### Character Encoding
- The bundle file should be UTF-8 encoded
- Line endings can be either LF (\n) or CRLF (\r\n)
- All markers use ASCII characters only

#### Header Format
```
###BUNDLE_ROOT:directory_name###
###BUNDLE_DATE:YYYY-MM-DDThh:mm:ssZ###

```
- `BUNDLE_ROOT`: The name of the root directory to create when unbundling
- `BUNDLE_DATE`: ISO 8601 formatted UTC timestamp of bundle creation
- Header must end with an empty line

#### File Entry Format
```
###START_FILE:path/to/file###
###METADATA:mode:uid:gid:mtime###
###SIZE:bytes###
[file contents]
###END_FILE:path/to/file###

```
- `path/to/file`: Relative path from root directory
- `mode`: Unix file permissions in octal (e.g., 644)
- `uid`: Unix user ID
- `gid`: Unix group ID
- `mtime`: Unix timestamp (seconds since epoch)
- `bytes`: File size in bytes
- File contents are included verbatim between SIZE and END_FILE markers

#### Directory Entry Format
```
###START_DIR:path/to/directory###
###METADATA:mode:uid:gid:mtime###
###END_DIR:path/to/directory###

```
- Similar to file entries but without SIZE or content sections
- Used for preserving empty directories and their attributes

### Example
```
###BUNDLE_ROOT:my-project###
###BUNDLE_DATE:2024-11-05T12:34:56Z###

###START_FILE:src/main.py###
###METADATA:644:1000:1000:1699123456###
###SIZE:42###
def main():
    print("Hello, World!")

if __name__ == "__main__":
    main()
###END_FILE:src/main.py###

###START_DIR:src/empty_dir###
###METADATA:755:1000:1000:1699123456###
###END_DIR:src/empty_dir###

```

### Implementation Notes

#### Parsing Guidelines
1. Markers must be on their own line
2. Metadata fields must be colon-separated
3. Empty line after each entry is recommended but optional
4. File paths should use forward slashes (/) even on Windows
5. All numeric values should be in decimal unless specified otherwise

#### Security Considerations
Implementations should:
1. Validate all paths to prevent directory traversal
2. Verify size matches content length
3. Handle permission bits appropriately
4. Sanitize metadata values
5. Consider resource limits (max path length, file size)

#### Error Handling
Implementations should handle:
1. Missing or malformed markers
2. Invalid metadata values
3. Truncated content
4. I/O errors during extraction
5. Permission and ownership issues

#### Optional Features
Implementations may support:
1. Compression of the bundle file
2. Digital signatures for verification
3. Encryption of sensitive content
4. Extended attributes or ACLs
5. Platform-specific metadata

### Command Line Interface Recommendations
For compatibility, tools should support:
```bash
# Creating bundles
bundle [options] <input_paths...> [-o output.txt]

# Extracting bundles
unbundle [options] [input.txt] [output_dir]

# Common options
--force           # Overwrite existing files
--preview         # List contents without extracting
```

### Version History
- 1.0.0: Initial format specification
  - Basic file and directory support
  - Unix-style metadata
  - UTF-8 text encoding

## See Also

* ar - create and maintain library archives
* tar - manipulate tape archives

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
