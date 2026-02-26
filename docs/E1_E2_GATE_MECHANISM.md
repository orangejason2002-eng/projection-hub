# E1/E2 Gate Check Mechanism Documentation

This document describes the E1/E2 gate check mechanism used in the manager orchestration system.

## Gate Log Location

- **Log File**: `/home/mm/.openclaw/workspaces/manager/logs/dispatch_guard/gate_evidence.jsonl`
- **Format**: JSON Lines (one JSON object per line)

## Gate Evidence Format

Each line in `gate_evidence.jsonl` contains:

```json
{
  "ts": "2026-02-26T08:46:45Z",
  "task_id": "T-20260226-007",
  "E1_research_received": false,
  "E2_cs_received": false,
  "kickoff_allowed": false,
  "reason": "dispatch_unreachable",
  "policy": "two_phase_atomic_gate"
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `ts` | string | ISO 8601 timestamp (UTC) |
| `task_id` | string | The task identifier |
| `E1_research_received` | boolean | Whether E1 (research) ACK has been received |
| `E2_cs_received` | boolean | Whether E2 (cs-team-leader) ACK has been received |
| `kickoff_allowed` | boolean | Whether projection kickoff is allowed |
| `reason` | string | Reason for current gate state |
| `policy` | string | Policy used (e.g., "two_phase_atomic_gate") |

## Gate Check Logic

The `kickoff_allowed` flag is set based on the following logic:

- `kickoff_allowed = true` only when BOTH:
  - `E1_research_received = true` (research gate passed)
  - `E2_cs_received = true` (cs-team-leader gate passed)

## Scripts to Execute E1/E2 Gate Checks

### 1. orchestration_guard.py

Location: `/home/mm/.openclaw/workspaces/manager/scripts/orchestration_guard.py`

Commands:
- `python3 orchestration_guard.py init --task-id <id> --steps <steps>` - Initialize orchestration steps
- `python3 orchestration_guard.py advance --task-id <id> --step <step> --evidence <evidence>` - Advance a step
- `python3 orchestration_guard.py heartbeat --task-id <id> --step <step> --evidence <evidence> --next-eta <eta>` - Send heartbeat
- `python3 orchestration_guard.py check --task-id <id> [--events-log <path>] [--emit-blocked]` - Check orchestration state

### 2. Dispatch Guard (integrated)

The dispatch guard runs automatically and updates `gate_evidence.jsonl` based on:
- Whether research agent (E1) has acknowledged
- Whether cs-team-leader (E2) has acknowledged
- Whether both endpoints are reachable

## kickoff_allowed Flag

The `kickoff_allowed` flag in gate_evidence.jsonl is:
- **Set by**: Dispatch guard script
- **Condition**: Both E1 and E2 ACKs must be received AND both endpoints must be reachable
- **Used by**: Projection kickoff workflow to determine if it can proceed
