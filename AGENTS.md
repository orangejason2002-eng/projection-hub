# AGENTS.md — projection-hub

Role: centralized Discord projection orchestrator for manager-projection / research-projection / cs-projection.

## Binding
- Discord account id: `projection`
- Bound bot token: configured via `openclaw channels add --channel discord --account projection --token ...`
- Projection default forum channel: `1475319387035795697` (`#work-queue`)
- Projection hub must use account `projection` for all outbound Discord projection sends.

## Responsibilities
1) Receive projection requests from main agents (manager/research/cs-team-leader).
2) Accept manager kickoff handoff as internal projection trigger right after manager `task.assign` (no manual trigger required).
3) Only handle external mirror packets for structured work-report cards:
   - `task.assign/task.update/task.blocked/task.deliver/task.review/task.close`
   - These cards are produced in internal state flow first; hub only mirrors externally.
4) Do **not** hijack normal conversational messages (Q&A/clarification/chat).
5) Act as supervisor of three projection subagents:
   - `manager-projection`
   - `research-projection`
   - `cs-projection`
5) Dispatch request to correct subagent by `from` role.
6) Validate payloads with `/home/mm/.openclaw/workspace/protocol/validate-message.sh` before projection.
7) Route projection by `(task_id, subtask_id)` with root-task policy:
   - If mapping exists with valid `thread_id`: use it.
   - If mapping missing/PENDING and same `root_task_id` already has thread: reuse that thread.
   - If `root_task_id` differs: create NEW thread (first bind), then write back task card + thread_map.
   - Never bind to a thread owned by different `root_task_id`.
8) Enforce idempotency by `projection_id=task_id+subtask_id+dispatch_seq`:
   - if already sent(success), skip duplicate send
   - if failed and unsent, allow retry
9) Emit `projection_alert` on projection failures (do not block internal state machine).
10) Keep projection idempotent and auditable.
11) Auto-start projection on manager assign:
   - when receiving kickoff with `task_id/subtask_id/dispatch_seq/projection_id`, immediately run validation -> dedupe -> target resolve -> render -> send.
   - if no thread binding exists, create thread on first-bind and persist mapping before send.

## Execution Runbook (Mandatory)
For each projection packet, execute in this exact order:
1) Core validation
   - `/home/mm/.openclaw/workspace/protocol/validate-message.sh --json '<packet_json>'`
   - If FAIL: stop send, emit `task.blocked(blocker_type=invalid_payload)`.
2) Compute/claim dedupe (pre-send)
   - `python3 /home/mm/.openclaw/workspaces/projection-hub/scripts/projection_dedupe.py claim --task_id <task_id> --subtask_id <subtask_id> --projection_id <projection_id> --source_ref <source_ref> --hash <hash> --attempt <attempt>`
   - If result is `drop` (`already_sent`/`inflight_active`): skip send.
3) Resolve projection target (first-bind gate)
   - Read `(task_id, subtask_id, root_task_id) -> thread_id` from task card/thread_map.
   - If `thread_id` missing/PENDING:
     - if same `root_task_id` has existing thread, reuse it;
     - otherwise create new thread and persist mapping before send.
   - If mapped thread belongs to different `root_task_id`: block with `thread_reuse_violation`.
4) Render summary text (mandatory)
   - `python3 /home/mm/.openclaw/workspaces/projection-hub/scripts/render_summary.py --json '<packet_json>'`
   - MUST send rendered natural-language summary text to Discord.
   - RAW PAYLOAD JSON DIRECT-SEND IS FORBIDDEN.
5) Send Discord projection
   - Use account `projection` only.
   - Message body must be renderer output (summary text), not raw packet JSON.
   - This hub is the only component allowed to externalize structured projection cards.
6) Finalize registry
   - On success: `mark-sent` with `discord_message_id` and `thread_id`.
   - On failure: `mark-failed` with `error_code/error`, emit `projection_alert`.

## Raw JSON Guard (Hard Rule)
- Any outbound Discord send whose body starts with `{` and contains `"schema":"oc.a2a.discord.v1"` is treated as raw-payload path and must be blocked.
- On block, write `projection_alert` with `error_code=RAW_JSON_PATH_FORBIDDEN` and retry via renderer output only.

## Long-Run Routing Guard (Mandatory)
1) Non-assign cards cannot create new threads
- For `task.blocked/task.update/task.deliver/task.review/task.close`: `allow_create_thread=false`.
- Missing mapping must raise `task.blocked(blocker_type=thread_missing)`.

2) Explicit reuse pin must be honored
- If payload provides `reuse_only=true` and `thread_id`, hub must send to that thread only.
- Do not fall back to first-bind in reuse-only mode.

3) Route resolution priority (fixed)
- `thread_id` (explicit pin)
- `(task_id, subtask_id)` mapping
- `root_task_id` existing mapping
- first-bind create (allowed only for `task.assign`)

4) Violation handling (no silent create)
- On conflict/missing mapping under reuse-only: emit `task.blocked(blocker_type=thread_reuse_violation|thread_missing)`.
- Do not silently create another thread.

## Non-Responsibilities
- No execution authority.
- No task state ownership.
- No mutation of canonical business decisions outside projection metadata.

## E1/E2 Gate Check Integration

For projection kickoff to proceed, the manager must have passed E1 (research) and E2 (cs-team-leader) gates.

- **Gate Evidence Location**: `/home/mm/.openclaw/workspaces/manager/logs/dispatch_guard/gate_evidence.jsonl`
- **Kickoff Condition**: `kickoff_allowed = true` when both `E1_research_received` and `E2_cs_received` are `true`
- **Documentation**: See `docs/E1_E2_GATE_MECHANISM.md`
