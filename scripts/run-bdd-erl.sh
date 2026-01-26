#!/usr/bin/env bash
set -euo pipefail

# Erlang BDD Runner
#
# Executes BDD feature scenarios against the Erlang backend.
# Uses Nix to compile PureScript to Erlang and runs the tests.
#
# Usage:
#   ./scripts/run-bdd-erl.sh [feature-file]
#
# Examples:
#   ./scripts/run-bdd-erl.sh                          # Run all features
#   ./scripts/run-bdd-erl.sh test/features/parallel-cancellation.feature.md
#
# Output is captured in out/test/bdd-erl/ for assertion-based verification.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/out/test/bdd-erl"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Feature file argument (optional)
FEATURE_FILE="${1:-}"

echo "=== Erlang BDD Runner ==="
echo ""

# Build the Erlang test app
echo "Building Erlang test app..."
if ! nix build "${PROJECT_ROOT}#test-concurrent-erl-beam" --no-link 2>"${OUTPUT_DIR}/build-stderr.txt"; then
    echo "ERROR: Failed to build Erlang test app"
    cat "${OUTPUT_DIR}/build-stderr.txt"
    exit 1
fi
echo "Build successful"
echo ""

# Get the store path for the compiled BEAM files
BEAM_PATH=$(nix build "${PROJECT_ROOT}#test-concurrent-erl-beam" --print-out-paths)

# Create the escript runner
ESCRIPT_RUNNER="${OUTPUT_DIR}/test-runner.escript"
cat > "${ESCRIPT_RUNNER}" << EOF
#!/usr/bin/env escript
%%! -pa ${BEAM_PATH}/ebin

main(_) ->
    F = 'test_monadConcurrent_main@ps':main(),
    F().
EOF

# Make escript executable
chmod +x "${ESCRIPT_RUNNER}"

# Run the tests and capture output
echo "Running Erlang tests..."
echo ""

STDOUT_FILE="${OUTPUT_DIR}/stdout.txt"
STDERR_FILE="${OUTPUT_DIR}/stderr.txt"
COMBINED_FILE="${OUTPUT_DIR}/output.txt"

# Execute the escript using nix-shell to get erlang in PATH
# This ensures escript is available even outside nix develop
set +e
nix shell nixpkgs#erlang -c escript "${ESCRIPT_RUNNER}" > "${STDOUT_FILE}" 2> "${STDERR_FILE}"
EXIT_CODE=$?
set -e

# Combine stdout and stderr for complete output
cat "${STDOUT_FILE}" "${STDERR_FILE}" > "${COMBINED_FILE}"

# Display output
cat "${STDOUT_FILE}"

if [ -s "${STDERR_FILE}" ]; then
    echo ""
    echo "=== Stderr ==="
    cat "${STDERR_FILE}"
fi

# Parse results for summary
echo ""
echo "=== Summary ==="

RESULT_STATUS="unknown"
if grep -q "All tests passed" "${STDOUT_FILE}"; then
    echo "Status: PASSED"
    RESULT_STATUS="passed"
elif grep -q "Some tests failed" "${STDOUT_FILE}"; then
    echo "Status: FAILED"
    RESULT_STATUS="failed"
else
    echo "Status: UNKNOWN"
fi

# Extract test counts (use || true to prevent errexit on no matches)
PASS_COUNT=$(grep -c "^\[PASS\]" "${STDOUT_FILE}" 2>/dev/null || true)
FAIL_COUNT=$(grep -c "^\[FAIL\]" "${STDOUT_FILE}" 2>/dev/null || true)

# Default to 0 if empty
PASS_COUNT="${PASS_COUNT:-0}"
FAIL_COUNT="${FAIL_COUNT:-0}"

# Ensure numeric values
PASS_COUNT=$((PASS_COUNT + 0))
FAIL_COUNT=$((FAIL_COUNT + 0))
TOTAL_COUNT=$((PASS_COUNT + FAIL_COUNT))

echo "Tests: ${PASS_COUNT} passed, ${FAIL_COUNT} failed, ${TOTAL_COUNT} total"
echo ""
echo "Output saved to: ${OUTPUT_DIR}"
echo "  - stdout.txt: Standard output"
echo "  - stderr.txt: Standard error"
echo "  - output.txt: Combined output"

# Write JSON result for BDD assertions
RESULT_JSON="${OUTPUT_DIR}/result.json"
cat > "${RESULT_JSON}" << EOF
{
  "status": "${RESULT_STATUS}",
  "passed": ${PASS_COUNT},
  "failed": ${FAIL_COUNT},
  "total": ${TOTAL_COUNT},
  "exitCode": ${EXIT_CODE}
}
EOF

echo "  - result.json: Structured results"

# Exit with appropriate code
if [ "${RESULT_STATUS}" = "passed" ]; then
    exit 0
elif [ "${RESULT_STATUS}" = "failed" ]; then
    exit 1
else
    exit "${EXIT_CODE}"
fi
