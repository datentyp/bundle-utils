#!/bin/bash

# Set up test environment
rm -rf test_exclude
mkdir -p test_exclude/src/{a,b,c}

# Create test files
echo "content1" > test_exclude/src/a/file1.txt
echo "content2" > test_exclude/src/b/file2.txt
echo "content3" > test_exclude/src/c/file3.dat

# Test different exclude patterns
test_pattern() {
    local pattern="$1"
    local desc="$2"
    
    echo "Testing: $desc"
    echo "Pattern: $pattern"
    
    ../bundle.sh --no-git-ignore -f --exclude-pattern="$pattern" test_exclude
    
    echo "Files included in bundle:"
    grep "START_FILE:" bundle.txt || echo "No files found"
    echo "----------------------------------------"
}

# Run tests
test_pattern "*.txt" "Exclude all .txt files"
test_pattern "a/*" "Exclude everything in directory a"
test_pattern "**/file*.txt" "Exclude .txt files with names starting with 'file'"
test_pattern "**/b/**" "Exclude everything under directory b"

# Cleanup
rm -rf test_exclude bundle.txt
