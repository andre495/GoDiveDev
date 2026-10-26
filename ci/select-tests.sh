#!/usr/bin/env bash
# select-tests.sh - Selective test runner for GoDive iOS CI
#
# Parses ci/test-map.yml and changed files to emit -only-testing: flags.
# Outputs FULL when core paths change or no selective mapping applies.
#
# Usage:
#   ci/select-tests.sh                    # Diff against merge-base with main
#   ci/select-tests.sh --base <ref>       # Diff against specific ref
#   ci/select-tests.sh --files <file>...  # Use explicit file list
#   ci/select-tests.sh --self-test        # Run built-in verification
#
# Exit codes:
#   0 - Success
#   1 - Error (missing dependencies, invalid input)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_MAP="$SCRIPT_DIR/test-map.yml"

# Dependency check
command -v yq >/dev/null 2>&1 || {
    echo "Error: yq is required but not installed." >&2
    echo "Install with: brew install yq" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Determine which test suites to run based on changed files.

Options:
  --base <ref>       Diff against specific git ref (default: merge-base with main)
  --files <file>...  Use explicit file list instead of git diff
  --self-test        Run built-in verification checks
  --summary          Output markdown summary for GitHub Actions
  -h, --help         Show this help message

Output:
  Prints space-separated -only-testing:GoDiveMVPTests/<Suite> flags,
  or "FULL" if the full test suite should run.

Examples:
  # Normal CI usage (diff against merge-base)
  ci/select-tests.sh

  # Test with specific files
  ci/select-tests.sh --files GoDiveMVP/Data/DiveActivity*.swift

  # Generate summary for job step
  ci/select-tests.sh --summary >> "\$GITHUB_STEP_SUMMARY"
EOF
}

# Parse arguments
BASE_REF=""
EXPLICIT_FILES=()
SELF_TEST=false
SUMMARY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)
            BASE_REF="$2"
            shift 2
            ;;
        --files)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                EXPLICIT_FILES+=("$1")
                shift
            done
            ;;
        --self-test)
            SELF_TEST=true
            shift
            ;;
        --summary)
            SUMMARY=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Get changed files
get_changed_files() {
    if [[ ${#EXPLICIT_FILES[@]} -gt 0 ]]; then
        printf '%s\n' "${EXPLICIT_FILES[@]}"
        return
    fi

    local base
    if [[ -n "$BASE_REF" ]]; then
        base="$BASE_REF"
    else
        # Find merge-base with main (or origin/main if local main doesn't exist)
        if git rev-parse --verify main >/dev/null 2>&1; then
            base=$(git merge-base HEAD main 2>/dev/null || echo "main")
        else
            base=$(git merge-base HEAD origin/main 2>/dev/null || echo "origin/main")
        fi
    fi

    git diff --name-only "$base" HEAD 2>/dev/null || git diff --name-only HEAD~1 HEAD 2>/dev/null || echo ""
}

# Check if path matches a glob pattern (bash-native)
matches_glob() {
    local path="$1"
    local pattern="$2"

    # Convert glob to regex for more accurate matching
    # Handle ** (any path), * (any segment), ? (single char)
    local regex="$pattern"
    regex="${regex//\*\*/.*}"      # ** -> .*
    regex="${regex//\*/[^/]*}"     # * -> [^/]*
    regex="${regex//\?/.}"         # ? -> .
    regex="^${regex}$"

    [[ "$path" =~ $regex ]]
}

# Check if any file matches core paths
check_core_paths() {
    local files=("$@")
    local core_paths

    core_paths=$(yq -r '.core_paths[]' "$TEST_MAP" 2>/dev/null) || return 1

    for file in "${files[@]}"; do
        while IFS= read -r pattern; do
            if matches_glob "$file" "$pattern"; then
                echo "Core path match: $file -> $pattern" >&2
                return 0
            fi
        done <<< "$core_paths"
    done

    return 1
}

# Get suites for a changed file
get_suites_for_file() {
    local file="$1"
    local mapping_count

    mapping_count=$(yq '.mappings | length' "$TEST_MAP")

    for ((i=0; i<mapping_count; i++)); do
        local pattern
        pattern=$(yq -r ".mappings[$i].pattern" "$TEST_MAP")

        if matches_glob "$file" "$pattern"; then
            yq -r ".mappings[$i].suites[]" "$TEST_MAP" 2>/dev/null || true
        fi
    done
}

# Main selection logic
select_tests() {
    local changed_files
    mapfile -t changed_files < <(get_changed_files)

    # Filter to non-empty
    local files=()
    for f in "${changed_files[@]}"; do
        [[ -n "$f" ]] && files+=("$f")
    done

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "FULL"
        return
    fi

    # Check core paths first
    if check_core_paths "${files[@]}"; then
        echo "FULL"
        return
    fi

    # Collect suites from all changed files
    local all_suites=()
    local unmapped_files=()

    for file in "${files[@]}"; do
        local file_suites
        mapfile -t file_suites < <(get_suites_for_file "$file")

        if [[ ${#file_suites[@]} -eq 0 ]]; then
            # Check if file is in a path we care about
            if [[ "$file" =~ ^(GoDiveMVP|GoDiveMVPTests)/ ]]; then
                unmapped_files+=("$file")
            fi
        else
            all_suites+=("${file_suites[@]}")
        fi
    done

    # If any app/test files are unmapped, run full suite (fail-safe)
    if [[ ${#unmapped_files[@]} -gt 0 ]]; then
        echo "Unmapped files (running full suite): ${unmapped_files[*]}" >&2
        echo "FULL"
        return
    fi

    # Deduplicate and sort suites
    if [[ ${#all_suites[@]} -eq 0 ]]; then
        # No relevant files changed (e.g., only docs, scripts, etc.)
        echo "NO_TESTS"
        return
    fi

    local unique_suites
    mapfile -t unique_suites < <(printf '%s\n' "${all_suites[@]}" | sort -u)

    # Output -only-testing flags
    local flags=()
    for suite in "${unique_suites[@]}"; do
        [[ -n "$suite" ]] && flags+=("-only-testing:GoDiveMVPTests/$suite")
    done

    echo "${flags[*]}"
}

# Generate markdown summary
generate_summary() {
    local result="$1"
    local changed_files
    mapfile -t changed_files < <(get_changed_files)

    echo "## Test Selection Summary"
    echo ""

    if [[ "$result" == "FULL" ]]; then
        echo "**Running:** Full test suite"
        echo ""
        echo "**Reason:** Core path changed or unmapped files detected"
    elif [[ "$result" == "NO_TESTS" ]]; then
        echo "**Running:** No iOS tests"
        echo ""
        echo "**Reason:** No app or test files changed"
    else
        local suite_count
        suite_count=$(echo "$result" | tr ' ' '\n' | wc -l | tr -d ' ')
        echo "**Running:** $suite_count selective suite(s)"
        echo ""
        echo "**Suites:**"
        echo '```'
        echo "$result" | tr ' ' '\n' | sed 's/-only-testing:GoDiveMVPTests\//- /'
        echo '```'
    fi

    echo ""
    echo "**Changed files:** ${#changed_files[@]}"
    if [[ ${#changed_files[@]} -le 20 ]]; then
        echo ""
        echo "<details><summary>Files</summary>"
        echo ""
        printf '- `%s`\n' "${changed_files[@]}"
        echo ""
        echo "</details>"
    fi
}

# Self-test verification
run_self_test() {
    local pass=0
    local fail=0

    test_case() {
        local name="$1"
        local expected="$2"
        shift 2
        local files=("$@")

        local result
        result=$("$0" --files "${files[@]}" 2>/dev/null)

        if [[ "$result" == *"$expected"* ]]; then
            echo "✓ $name"
            ((pass++)) || true
        else
            echo "✗ $name"
            echo "  Expected: $expected"
            echo "  Got: $result"
            ((fail++)) || true
        fi
    }

    echo "Running self-tests..."
    echo ""

    # Core path triggers full suite
    test_case "Core: project file" "FULL" "GoDiveMVP.xcodeproj/project.pbxproj"
    test_case "Core: account session" "FULL" "GoDiveMVP/Data/AccountSession.swift"
    test_case "Core: CI workflow" "FULL" ".github/workflows/ios-ci.yml"
    test_case "Core: test map" "FULL" "ci/test-map.yml"

    # Specific mappings
    test_case "Map: dive activity" "DiveActivityLogbookTests" "GoDiveMVP/Data/DiveActivityStore.swift"
    test_case "Map: buddies" "DiveBuddyTests" "GoDiveMVP/Data/DiveBuddyStore.swift"
    test_case "Map: trips" "TripPlannerTests" "GoDiveMVP/Data/TripStore.swift"
    test_case "Map: equipment" "EquipmentTests" "GoDiveMVP/Data/EquipmentStore.swift"
    test_case "Map: test file direct" "AccountOnboardingTests" "GoDiveMVPTests/AccountOnboardingTests.swift"

    # Non-app files should not trigger tests
    test_case "Skip: readme" "NO_TESTS" "README.md"
    test_case "Skip: docs" "NO_TESTS" "docs/index.md"

    # Multiple files combine suites
    local multi_result
    multi_result=$("$0" --files "GoDiveMVP/Data/DiveActivityStore.swift" "GoDiveMVP/Data/TripStore.swift" 2>/dev/null)
    if [[ "$multi_result" == *"DiveActivityLogbookTests"* && "$multi_result" == *"TripPlannerTests"* ]]; then
        echo "✓ Multi-file combines suites"
        ((pass++)) || true
    else
        echo "✗ Multi-file combines suites"
        echo "  Expected: contains DiveActivityLogbookTests and TripPlannerTests"
        echo "  Got: $multi_result"
        ((fail++)) || true
    fi

    echo ""
    echo "Results: $pass passed, $fail failed"

    [[ $fail -eq 0 ]]
}

# Main
if $SELF_TEST; then
    run_self_test
    exit $?
fi

result=$(select_tests)

if $SUMMARY; then
    generate_summary "$result"
else
    echo "$result"
fi
