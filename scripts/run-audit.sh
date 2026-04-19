#!/usr/bin/env bash
set -uo pipefail

# Resolve the proof binary
if [ -n "${INPUT_PROOF_PATH:-}" ]; then
  PROOF="$INPUT_PROOF_PATH"
  if [ ! -x "$PROOF" ]; then
    echo "::error::proof binary not found or not executable at ${PROOF}"
    exit 1
  fi
else
  PROOF="proof"
fi

# Move to the working directory
cd "${INPUT_WORKING_DIRECTORY:-.}" || {
  echo "::error::Working directory '${INPUT_WORKING_DIRECTORY}' does not exist"
  exit 1
}

# Check that this looks like a reqproof project
if [ ! -f "reqproof.yaml" ] && [ ! -f "proof.yaml" ] && [ ! -d "specs" ]; then
  echo "::warning::No reqproof.yaml, proof.yaml, or specs/ directory found. This may not be a ReqProof project."
  echo "::notice::Skipping audit -- not a ReqProof project."
  {
    echo "exit-code=0"
    echo "errors=0"
    echo "warnings=0"
    echo "summary=Skipped: not a ReqProof project"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

# Build the audit command
CMD=("$PROOF" "audit")

if [ -n "${INPUT_FAIL_LEVEL:-}" ]; then
  CMD+=("--fail-level" "$INPUT_FAIL_LEVEL")
fi

if [ -n "${INPUT_FORMAT:-}" ]; then
  CMD+=("--format" "$INPUT_FORMAT")
fi

if [ -n "${INPUT_SCOPE:-}" ]; then
  CMD+=("--scope" "$INPUT_SCOPE")
fi

if [ -n "${INPUT_CHECK:-}" ]; then
  IFS=',' read -ra CHECKS <<< "$INPUT_CHECK"
  for c in "${CHECKS[@]}"; do
    CMD+=("--check" "$(echo "$c" | xargs)")
  done
fi

if [ -n "${INPUT_STAGE:-}" ]; then
  IFS=',' read -ra STAGES <<< "$INPUT_STAGE"
  for s in "${STAGES[@]}"; do
    CMD+=("--stage" "$(echo "$s" | xargs)")
  done
fi

echo "::group::Running ReqProof Audit"
echo "Command: ${CMD[*]}"
echo ""

# Run the audit and capture output
OUTPUT_FILE="$(mktemp)"
"${CMD[@]}" 2>&1 | tee "$OUTPUT_FILE"
AUDIT_EXIT_CODE=${PIPESTATUS[0]}

echo "::endgroup::"

# Parse results from the output
ERRORS=0
WARNINGS=0
SUMMARY=""

# Try to extract counts from the output
if grep -qE '[0-9]+ error' "$OUTPUT_FILE"; then
  ERRORS=$(grep -oE '[0-9]+ error' "$OUTPUT_FILE" | tail -1 | grep -oE '^[0-9]+')
fi
if grep -qE '[0-9]+ warning' "$OUTPUT_FILE"; then
  WARNINGS=$(grep -oE '[0-9]+ warning' "$OUTPUT_FILE" | tail -1 | grep -oE '^[0-9]+')
fi

# Build a summary line
case $AUDIT_EXIT_CODE in
  0) SUMMARY="Audit passed: ${ERRORS} errors, ${WARNINGS} warnings" ;;
  1) SUMMARY="Audit failed: ${ERRORS} errors, ${WARNINGS} warnings" ;;
  2) SUMMARY="Audit warnings: ${ERRORS} errors, ${WARNINGS} warnings" ;;
  *) SUMMARY="Audit exited with code ${AUDIT_EXIT_CODE}" ;;
esac

# Write to GitHub step summary if format is markdown
if [ "${INPUT_FORMAT:-}" = "markdown" ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## ReqProof Audit Results"
    echo ""
    cat "$OUTPUT_FILE"
    echo ""
    echo "---"
    echo "*${SUMMARY}*"
  } >> "$GITHUB_STEP_SUMMARY"
fi

# Set outputs
{
  echo "exit-code=${AUDIT_EXIT_CODE}"
  echo "errors=${ERRORS}"
  echo "warnings=${WARNINGS}"
  echo "summary=${SUMMARY}"
} >> "$GITHUB_OUTPUT"

rm -f "$OUTPUT_FILE"

# Exit with the audit's exit code
exit $AUDIT_EXIT_CODE
