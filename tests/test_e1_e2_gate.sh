#!/bin/bash
# Test: E1/E2 Gate Mechanism Documentation Validation
# This test verifies that the gate_evidence.jsonl format matches the documented format

GATE_EVIDENCE_PATH="/home/mm/.openclaw/workspaces/manager/logs/dispatch_guard/gate_evidence.jsonl"

echo "=== E1/E2 Gate Mechanism Documentation Tests ==="

# Test 1: Gate evidence file exists
echo "Test 1: Gate evidence file exists"
if [ -f "$GATE_EVIDENCE_PATH" ]; then
    echo "PASS: $GATE_EVIDENCE_PATH exists"
else
    echo "FAIL: $GATE_EVIDENCE_PATH does not exist"
    exit 1
fi

# Test 2: Gate evidence has valid JSON lines
echo "Test 2: Gate evidence has valid JSON"
while IFS= read -r line; do
    if [ -n "$line" ]; then
        if echo "$line" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
            echo "PASS: Valid JSON line: $line"
        else
            echo "FAIL: Invalid JSON line: $line"
            exit 1
        fi
    fi
done < "$GATE_EVIDENCE_PATH"

# Test 3: Required fields are present
echo "Test 3: Required fields present in gate evidence"
REQUIRED_FIELDS=("ts" "task_id" "E1_research_received" "E2_cs_received" "kickoff_allowed" "reason" "policy")

last_line=$(tail -n 1 "$GATE_EVIDENCE_PATH")
for field in "${REQUIRED_FIELDS[@]}"; do
    if echo "$last_line" | python3 -c "import json, sys; d=json.load(sys.stdin); sys.exit(0 if '$field' in d else 1)" 2>/dev/null; then
        echo "PASS: Field '$field' exists"
    else
        echo "FAIL: Field '$field' missing"
        exit 1
    fi
done

# Test 4: kickoff_allowed is boolean
echo "Test 4: kickoff_allowed is boolean"
if echo "$last_line" | python3 -c "import json, sys; d=json.load(sys.stdin); assert isinstance(d.get('kickoff_allowed'), bool)" 2>/dev/null; then
    echo "PASS: kickoff_allowed is boolean"
else
    echo "FAIL: kickoff_allowed is not boolean"
    exit 1
fi

# Test 5: E1 and E2 fields are boolean
echo "Test 5: E1/E2 fields are boolean"
if echo "$last_line" | python3 -c "import json, sys; d=json.load(sys.stdin); assert isinstance(d.get('E1_research_received'), bool); assert isinstance(d.get('E2_cs_received'), bool)" 2>/dev/null; then
    echo "PASS: E1 and E2 fields are boolean"
else
    echo "FAIL: E1/E2 fields are not boolean"
    exit 1
fi

# Test 6: Orchestration guard script exists
echo "Test 6: Orchestration guard script exists"
if [ -f "/home/mm/.openclaw/workspaces/manager/scripts/orchestration_guard.py" ]; then
    echo "PASS: orchestration_guard.py exists"
else
    echo "FAIL: orchestration_guard.py not found"
    exit 1
fi

# Test 7: Script has required commands
echo "Test 7: Orchestration guard has required commands"
if grep -q "def cmd_init" /home/mm/.openclaw/workspaces/manager/scripts/orchestration_guard.py && \
   grep -q "def cmd_advance" /home/mm/.openclaw/workspaces/manager/scripts/orchestration_guard.py && \
   grep -q "def cmd_check" /home/mm/.openclaw/workspaces/manager/scripts/orchestration_guard.py; then
    echo "PASS: Required commands (init, advance, check) present"
else
    echo "FAIL: Missing required commands"
    exit 1
fi

# Test 8: Documentation file exists
echo "Test 8: Documentation file exists"
if [ -f "/home/mm/.openclaw/workspaces/projection-hub/docs/E1_E2_GATE_MECHANISM.md" ]; then
    echo "PASS: Documentation exists"
else
    echo "FAIL: Documentation not found"
    exit 1
fi

echo ""
echo "=== All Tests Passed ==="
exit 0
