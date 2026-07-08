#!/bin/bash

# Test script for ping parsing
# Tests argument handling, flags (-? and -v), and exit statuses

PING_BIN="${1:-./ping}"
PASSED=0
FAILED=0
TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Test function
# Usage: run_test "test_name" expected_exit_code "expected_stdout_pattern" "expected_stderr_pattern" args...
run_test() {
    local test_name="$1"
    local expected_exit="$2"
    local expected_stdout="$3"
    local expected_stderr="$4"
    shift 4
    local args=("$@")

    ((TOTAL++))

    # Run the command and capture output
    local stdout stderr exit_code
    stdout=$("$PING_BIN" "${args[@]}" 2>/dev/null)
    stderr=$("$PING_BIN" "${args[@]}" 2>&1 >/dev/null)
    "$PING_BIN" "${args[@]}" >/dev/null 2>&1
    exit_code=$?

    local test_passed=true
    local failure_reasons=""

    # Check exit code
    if [[ "$exit_code" -ne "$expected_exit" ]]; then
        test_passed=false
        failure_reasons+="  Exit code: got $exit_code, expected $expected_exit\n"
    fi

    # Check stdout pattern (if provided)
    if [[ -n "$expected_stdout" ]] && ! echo "$stdout" | grep -qE "$expected_stdout"; then
        test_passed=false
        failure_reasons+="  Stdout: expected pattern '$expected_stdout' not found\n"
        failure_reasons+="  Got: $stdout\n"
    fi

    # Check stderr pattern (if provided)
    if [[ -n "$expected_stderr" ]] && ! echo "$stderr" | grep -qE "$expected_stderr"; then
        test_passed=false
        failure_reasons+="  Stderr: expected pattern '$expected_stderr' not found\n"
        failure_reasons+="  Got: $stderr\n"
    fi

    if $test_passed; then
        echo -e "${GREEN}[PASS]${RESET} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${RESET} $test_name"
        echo -e "$failure_reasons"
        ((FAILED++))
    fi
}

# Simpler test for just exit code
run_test_exit() {
    local test_name="$1"
    local expected_exit="$2"
    shift 2
    local args=("$@")

    ((TOTAL++))

    "$PING_BIN" "${args[@]}" >/dev/null 2>&1
    local exit_code=$?

    if [[ "$exit_code" -eq "$expected_exit" ]]; then
        echo -e "${GREEN}[PASS]${RESET} $test_name (exit: $exit_code)"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${RESET} $test_name"
        echo -e "  Exit code: got $exit_code, expected $expected_exit"
        ((FAILED++))
    fi
}

# Test for non-zero exit (any error)
run_test_error() {
    local test_name="$1"
    shift 1
    local args=("$@")

    ((TOTAL++))

    "$PING_BIN" "${args[@]}" >/dev/null 2>&1
    local exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        echo -e "${GREEN}[PASS]${RESET} $test_name (exit: $exit_code, non-zero as expected)"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${RESET} $test_name"
        echo -e "  Exit code: got $exit_code, expected non-zero"
        ((FAILED++))
    fi
}

# Test for zero exit (success)
run_test_success() {
    local test_name="$1"
    shift 1
    local args=("$@")

    ((TOTAL++))

    "$PING_BIN" "${args[@]}" >/dev/null 2>&1
    local exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        echo -e "${GREEN}[PASS]${RESET} $test_name (exit: 0)"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${RESET} $test_name"
        echo -e "  Exit code: got $exit_code, expected 0"
        ((FAILED++))
    fi
}

echo -e "${YELLOW}======================================${RESET}"
echo -e "${YELLOW}    Ping Parsing Tests${RESET}"
echo -e "${YELLOW}======================================${RESET}"
echo ""

# Check if binary exists
if [[ ! -x "$PING_BIN" ]]; then
    echo -e "${RED}Error: $PING_BIN not found or not executable${RESET}"
    echo "Usage: $0 [path_to_ping_binary]"
    exit 1
fi

echo -e "${YELLOW}Testing binary: $PING_BIN${RESET}"
echo ""

# ============================================
# NO ARGUMENTS TESTS
# ============================================
echo -e "${YELLOW}--- No Arguments ---${RESET}"

run_test_error "No arguments should fail"
run_test "No args: error message" 1 "" "usage error.*[Dd]estination"

# ============================================
# HELP FLAG TESTS (-?)
# ============================================
echo ""
echo -e "${YELLOW}--- Help Flag (-?) ---${RESET}"

run_test_error "Help flag alone should exit non-zero"  "-?"
run_test "Help flag shows usage" 1 "Usage" "" "-?"
run_test "Help flag shows options" 1 "Options" "" "-?"
run_test "Help flag mentions -v" 1 "verbose" "" "-?"
run_test "Help flag mentions -?" 1 "print help" "" "-?"

# -? with extra arguments (should still just show help)
run_test_error "Help with destination still shows help" "-?" "google.com"

# ============================================
# VERBOSE FLAG TESTS (-v)
# ============================================
echo ""
echo -e "${YELLOW}--- Verbose Flag (-v) ---${RESET}"

run_test_error "Verbose without destination should fail" "-v"
run_test "Verbose without dest: error message" 1 "" "usage error.*[Dd]estination" "-v"
run_test_success "Verbose with destination should succeed" "-v" "google.com"
run_test "Verbose mode outputs verbose message" 0 "[Vv]erbose" "" "-v" "google.com"

# ============================================
# UNKNOWN FLAG TESTS
# ============================================
echo ""
echo -e "${YELLOW}--- Unknown Flags ---${RESET}"

run_test_error "Unknown flag -x should fail" "-x"
run_test "Unknown flag -x: error message" 1 "" "invalid option" "-x"

run_test_error "Unknown flag -a should fail" "-a"
run_test_error "Unknown flag -z should fail" "-z"
run_test_error "Unknown flag --verbose should fail" "--verbose"
run_test_error "Unknown flag --help should fail" "--help"

# Unknown flag with destination
run_test_error "Unknown flag with destination should fail" "-x" "google.com"

# ============================================
# VALID DESTINATION TESTS
# ============================================
echo ""
echo -e "${YELLOW}--- Valid Destination ---${RESET}"

run_test_success "Single destination should succeed" "google.com"
run_test_success "IP address destination should succeed" "8.8.8.8"
run_test_success "Localhost should succeed" "localhost"
run_test_success "127.0.0.1 should succeed" "127.0.0.1"

run_test "Destination is used" 0 "google.com" "" "google.com"

# ============================================
# TOO MANY ARGUMENTS TESTS
# ============================================
echo ""
echo -e "${YELLOW}--- Too Many Arguments ---${RESET}"

run_test_error "Two destinations should fail" "google.com" "cloudflare.com"
run_test_error "Three destinations should fail" "a.com" "b.com" "c.com"
run_test_error "Verbose with two destinations should fail" "-v" "google.com" "cloudflare.com"

# ============================================
# EDGE CASES
# ============================================
echo ""
echo -e "${YELLOW}--- Edge Cases ---${RESET}"

run_test_success "Destination starting with number" "1google.com"
run_test_success "Destination with dashes" "my-server.example.com"
run_test_success "Single character destination" "a"

# Flag-like destinations (without leading dash should work)
run_test_success "Destination 'v' (not -v)" "v"
run_test_success "Destination '?' (not -?)" "?"

# Empty-ish arguments
run_test_error "Just a dash should be treated as unknown flag" "-"

# ============================================
# SUMMARY
# ============================================
echo ""
echo -e "${YELLOW}======================================${RESET}"
echo -e "${YELLOW}    Summary${RESET}"
echo -e "${YELLOW}======================================${RESET}"
echo -e "Total:  $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${RESET}"
echo -e "Failed: ${RED}$FAILED${RESET}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${RESET}"
    exit 0
else
    echo -e "${RED}Some tests failed.${RESET}"
    exit 1
fi
