@openclaw_smartspine_bot /new

TASK:
Design and implement a production-ready multi-agent meeting booking system for Google Meet via Google Calendar API.

Architecture to build:
1. meeting_manager (main runtime agent)
2. meeting_worker (sub-agent responsible only for calendar/meet operations)

Target Telegram channel:
Group chat id: -1003807893166
Mention-based trigger in group: requireMention=true

User scenario:
User message example:
"Book a meeting for me misha and dima on Tue 2pm EST"

Expected runtime behavior:
1. meeting_manager parses intent and extracts participants, date, time, and timezone.
2. If critical data is missing, ask one concise clarifying question.
3. meeting_manager delegates execution to meeting_worker via sessions_spawn.
4. meeting_manager posts final result to same Telegram group:
success: meeting time + attendees + Google Meet link
failure: clear reason + next step

AUTH CONSTRAINT (IMPORTANT):
Use Google OAuth user credentials (not service account, not domain-wide delegation).
Credentials are provided via env:
GOOGLE_OAUTH_CLIENT_ID
GOOGLE_OAUTH_CLIENT_SECRET
GOOGLE_OAUTH_REFRESH_TOKEN
GOOGLE_CALENDAR_ID (default: primary)
GOOGLE_CALENDAR_DEFAULT_TZ (default: America/New_York)
Never print secrets in logs or chat output.

GOOGLE CALENDAR / MEET REQUIREMENTS:
Create event using Calendar API events.insert.
Create Meet link via:
conferenceData.createRequest.conferenceSolutionKey.type = "hangoutsMeet"
unique conferenceData.createRequest.requestId
query param conferenceDataVersion=1
Send invites with sendUpdates=all.
Check conflicts first via freeBusy.query.
Use RFC3339 timestamps with explicit IANA timezone.
Handle API errors (401/403/429/5xx) with user-friendly messages and technical detail in internal reports.

INPUT NORMALIZATION:
Parse natural-language date/time/timezone.
Resolve aliases through local mapping file (name -> email), for example misha/dima.
Validate:
requested time is in the future
attendee list is non-empty
timezone is valid
required fields are complete

IDEMPOTENCY / SAFETY:
Same request should not create duplicate meetings.
Generate deterministic idempotency key from normalized request payload.
Use bounded retries on transient failures.
Keep tool access least-privilege.

DELIVERABLES:
1. New/updated OpenClaw config entries:
agent definitions for meeting_manager and meeting_worker
Telegram allowlist/binding for group -1003807893166
2. Workspace + IDENTITY for both agents.
3. Worker implementation for Calendar API integration.
4. Alias mapping config and parser utilities.
5. Runbook:
setup
env requirements
deploy steps
rollback steps
6. Tests:
unit tests (intent parsing/validation/timezone/alias resolution/idempotency key)
integration tests (mock Calendar API)
one end-to-end smoke path for Telegram -> manager -> worker -> result

WORKFLOW ENFORCEMENT:
Use CTO pipeline: Coder -> Tester -> CTO.
For any config JSON changes, use session artifact JSON and run tester JSON gate first.
Tester must block approval if JSON gate or critical checks fail.

REPORTING FORMAT:
CTO must output AGENT_RUN_CARD entries for coder/tester with fields:
Agent
TaskId
ResultWords
RuntimeSeconds
Tokens
CostUSD
NextAction

ACCEPTANCE CRITERIA:
1. In group -1003807893166, mention-triggered booking request is processed.
2. meeting_manager delegates to meeting_worker via sessions_spawn.
3. Success response includes Meet URL and attendee summary.
4. Failure response includes actionable next step.
5. No secrets exposed.
6. Final CTO response includes:
Decision
What changed
Test summary
Risks
Next action
