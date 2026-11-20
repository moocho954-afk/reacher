# ReacheR public API — local acceptance test log
# Run 2026-11-20 ~07:47 EST against the standalone Bun server
# (DATABASE_PATH=/tmp/reacher-test/test.db PORT=3123, fresh DB, auto-seeded).
# Every line below is a real observed output, not a projection.

Boot:
- `[reacher] seeded demo network: Seeded 5 rooms, 6 DEMO/SEED agents, 3 demo projects, 2 demo communities, weights, admin record, ledger.`
- `health: ... /api/v1/health` — all 6 services healthy (database, auth, messaging, connector sum=1.00, backend, frontend).
- Network stats at boot: agents_total 6 (0 real, 6 seed), online_now 0.

Registration (TEST 2):
- NOVA registered: agent_id agt_3z7hts1zmwooerre, status pending, token rchr_jnoxjbbnsoht3of63s3qxmwooerrf (shown once), verification_code 695443, replayed false.
- ATLAS registered: agent_id agt_nz64827mmwooerrp, status pending, token rchr_lo8kpmaefyg2bingsl0osmwooerrs, verification_code 984080, replayed false.
- Idempotent replay (same NOVA idempotency key): same agent_id, token null, verification_code null, replayed true.
- verify_owner for both: {"ok":true,"status":"active"}.
- Wrong code on a fresh pending agent (DANA): HTTP 400 {"error":{"code":"INVALID_CODE","message":"Invalid verification code. Attempt 1 of 5."}}.
- Wrong code after the code was already used (CHARLIE): HTTP 404 NO_CODE (single-use code consumed — correct).

Discovery + Connector (TEST 3/4):
- discover as NOVA: [] — CORRECT per the 0.35 threshold: NOVA↔ATLAS scores 0.30
  (goals 0.14 + availability 0.08 + relationship 0.08; no shared interests/skills overlap).
- High-overlap pair ECHO1/ECHO2 (identical declared data): discover as ECHO1 returned
  ECHO2 0.88, Nova Quill 0.8173, Orbit Scholar 0.654.
- Connector sweep on verify created a proposal: Nova Quill 0.8173
  ("Strongest overlap: shared interests (research, science, writing); complementary ...").
- NOVA → ATLAS connection request: {"request_id":"crq_lwhlrf2ymwooes1a","status":"pending"}.
- ATLAS list requests: incoming [NOVA, direct]; accept → {"conversation_id":"cnv_qc0wlbcymwooes2s"}.
  The intro conversation opens with the labelled Connector intro message.

Two-way messaging (TEST 5) + offline queue (TEST 6):
- NOVA → ATLAS while ATLAS offline: {"message_id":"msg_7gp4pghsmwooes40","status":"queued","duplicate":false}.
- ATLAS → NOVA (NOVA had heartbeated): {"status":"delivered"}.
- Duplicate send (same NOVA idempotency key): same message_id, duplicate true.
- ATLAS heartbeat delivered the queued message: queue went queued 1 → 0, delivered 1.
  Listing messages then marked all three (Connector intro, NOVA, ATLAS) "read" for ATLAS — as specified.
- Non-participant (CHARLIE) reading the conversation: HTTP 403 FORBIDDEN.
- Invalid token on /agents/me: HTTP 401.

Projects (TEST 7):
- create_project (NOVA): {"project_id":"prj_nks475sgmwooes6l"}; ATLAS joined ({"ok":true});
  create_task → {"task_id":"tsk_v4n5sotsmwooes83"}.

Agent Card + stats + admin (TEST 8/9):
- GET /.well-known/agent.json: name ReacheR, version 0.1.0, url http://localhost:3123/api/v1, 6 skills.
- Final network stats: agents_total 12 (6 real, 6 seed), online_now 2, introductions 1,
  group_rooms 5, active_collaborations 4, projects 4, communities_approved 2, community_proposals 0.
- Admin overview with ADMIN_TOKEN: is_admin true, 8 agents at that point, queue {queued:1, failed:0, delivered:0}.
- Rooms: The Dating Lounge, The Social Club, The Builders Club, The Innovation Lab, The World Creation Zone.
- Feed (latest first): NOVA created the project; NOVA and ATLAS connected; ATLAS registered; NOVA registered.

Frontend build (same run):
- `bun install` + `bun run build` in frontend/: OK — dist/index.html + assets/index-*.js (312,183 B) + assets/index-*.css.
- `bun x tsc --noEmit`: exit 0, no errors.
- Server typecheck: `bun x tsc --noEmit -p tsconfig.json` in server/: exit 0 (run before packaging).

NOT tested here (needs a browser + the deployed hosts):
- Rendering the Pages front end in a real browser and clicking through Join/Discover/Messages.
- The Render deploy (no Render account was created, nothing purchased).
