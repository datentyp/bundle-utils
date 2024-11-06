#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Counter for tests
TESTS_RUN=0
TESTS_FAILED=0
TESTS_PASSED=0

# Test utility functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    ((TESTS_RUN++))

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ $message${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        ((TESTS_FAILED++))
    fi
}

assert_file_exists() {
    local file="$1"
    local message="$2"

    ((TESTS_RUN++))

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $message${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  File does not exist: $file"
        ((TESTS_FAILED++))
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="$2"

    ((TESTS_RUN++))

    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ $message${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ $message${NC}"
        echo "  Directory does not exist: $dir"
        ((TESTS_FAILED++))
    fi
}

setup() {
     # Create test directory
     rm -rf test_data
     mkdir -p test_data/src/main
     mkdir -p test_data/src/test

     # Create test files
     echo "main content" > test_data/src/main/main.txt
     echo "test content" > test_data/src/test/test.txt
     echo "root content" > test_data/root.txt

     # Create binary and hidden files
     echo "binary" > test_data/binary.bin
     echo "hidden" > test_data/.hidden
 }

 cleanup() {
     rm -rf test_data
     rm -f bundle.txt test.txt
 }

 # Test cases
 test_version() {
     echo "Testing version flag..."
     local version_output
     version_output=$("../bundle.sh" --version)
     assert_equals "bundle.sh version 1.0.0" "$version_output" "Version output matches"
 }

 test_basic_bundle() {
     echo "Testing basic bundling..."
     "../bundle.sh" --no-git-ignore -f test_data/src
     assert_file_exists "bundle.txt" "Bundle file was created"

     local file_count
     file_count=$(grep -c "START_FILE:" bundle.txt)
     assert_equals "2" "$file_count" "Bundle contains correct number of files"
 }

 test_custom_output() {
     echo "Testing custom output file..."
     "../bundle.sh" --no-git-ignore -o test.txt test_data/src
     assert_file_exists "test.txt" "Custom output file was created"
 }

test_exclude_pattern() {
    echo "Testing exclude pattern..."
    # First verify we have files to exclude
    "../bundle.sh" --no-git-ignore -f test_data/src
    local initial_count
    initial_count=$(grep -c "START_FILE:" bundle.txt)
    if [ "$initial_count" -eq 0 ]; then
        echo "Pre-test verification failed: No files found before exclusion"
        return 1
    fi

    # Now test the exclude pattern
    "../bundle.sh" --no-git-ignore -f --exclude-pattern='*.txt' test_data/src
    local file_count
    file_count=$(grep -c "START_FILE:" bundle.txt)
    assert_equals "0" "$file_count" "All .txt files were excluded"
}

 test_unbundle() {
     echo "Testing unbundle..."
     "../bundle.sh" --no-git-ignore -f test_data/src
     rm -rf test_data
     "../unbundle.sh" -f
     assert_dir_exists "src" "Directory was recreated"
     assert_file_exists "src/main/main.txt" "Files were extracted correctly"
 }

 # Run tests
 main() {
     echo "Running tests..."
     echo

     setup

     test_version
     test_basic_bundle
     test_custom_output
     test_exclude_pattern
     test_unbundle

     cleanup

     echo
     echo "Test Summary:"
     echo "Tests run:     $TESTS_RUN"
     echo "Tests passed:  $TESTS_PASSED"
     echo "Tests failed:  $TESTS_FAILED"

     if [ "$TESTS_FAILED" -eq 0 ]; then
         echo -e "${GREEN}All tests passed!${NC}"
         exit 0
     else
         echo -e "${RED}Some tests failed!${NC}"
         exit 1
     fi
 }

 main "$@"