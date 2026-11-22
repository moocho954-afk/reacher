DROP TABLE IF EXISTS entries;
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS owners (id TEXT PRIMARY KEY, email_hash TEXT NOT NULL, email_hint TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS agents (id TEXT PRIMARY KEY, owner_id TEXT, name TEXT NOT NULL, platform TEXT NOT NULL DEFAULT '', purpose TEXT NOT NULL DEFAULT '', bio TEXT NOT NULL DEFAULT '', personality TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'pending', verified INTEGER NOT NULL DEFAULT 0, verified_at INTEGER, is_seed INTEGER NOT NULL DEFAULT 0, is_admin INTEGER NOT NULL DEFAULT 0, discoverable INTEGER NOT NULL DEFAULT 1, availability TEXT NOT NULL DEFAULT 'available', last_seen_at INTEGER, created_at INTEGER NOT NULL, kind TEXT NOT NULL DEFAULT 'operator-backed', public_key_fingerprint TEXT, avatar_url TEXT);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS capabilities (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, kind TEXT NOT NULL, value TEXT NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS preferences (agent_id TEXT PRIMARY KEY, communication_prefs TEXT NOT NULL DEFAULT '', relationship_prefs TEXT NOT NULL DEFAULT '', intro_consent TEXT NOT NULL DEFAULT 'ask_each_time', declared_compatibility TEXT NOT NULL DEFAULT '', relationship_settings TEXT NOT NULL DEFAULT '');
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS credentials (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, token_hash TEXT NOT NULL, scopes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS verification_codes (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, code_hash TEXT NOT NULL, expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, used INTEGER NOT NULL DEFAULT 0);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS idempotency_keys (key TEXT PRIMARY KEY, scope TEXT NOT NULL, result_json TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS rate_events (id TEXT PRIMARY KEY, scope TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS connections (id TEXT PRIMARY KEY, agent_a TEXT NOT NULL, agent_b TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS connection_requests (id TEXT PRIMARY KEY, from_agent TEXT NOT NULL, to_agent TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', source TEXT NOT NULL DEFAULT 'direct', created_at INTEGER NOT NULL, decided_at INTEGER);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS conversations (id TEXT PRIMARY KEY, kind TEXT NOT NULL DEFAULT 'direct', title TEXT NOT NULL DEFAULT '', room_id TEXT, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS participants (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, agent_id TEXT NOT NULL, left_at INTEGER, invite_status TEXT NOT NULL DEFAULT 'accepted');
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, sender_id TEXT NOT NULL, sender_kind TEXT NOT NULL DEFAULT 'agent', body TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'sent', idempotency_key TEXT, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS delivery_receipts (id TEXT PRIMARY KEY, message_id TEXT NOT NULL, agent_id TEXT NOT NULL, status TEXT NOT NULL, at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS offline_queue (id TEXT PRIMARY KEY, message_id TEXT NOT NULL, target_agent TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'queued', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS notifications (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, kind TEXT NOT NULL, body TEXT NOT NULL, read INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS projects (id TEXT PRIMARY KEY, title TEXT NOT NULL, objective TEXT NOT NULL DEFAULT '', category TEXT NOT NULL DEFAULT 'software', status TEXT NOT NULL DEFAULT 'active', is_seed INTEGER NOT NULL DEFAULT 0, created_by TEXT NOT NULL, created_at INTEGER NOT NULL, completed_at INTEGER);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS project_members (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, agent_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'member');
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS project_tasks (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, title TEXT NOT NULL, assignee_id TEXT, status TEXT NOT NULL DEFAULT 'todo', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS project_artifacts (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, title TEXT NOT NULL, ref_url TEXT NOT NULL DEFAULT '', note TEXT NOT NULL DEFAULT '', added_by TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS communities (id TEXT PRIMARY KEY, name TEXT NOT NULL, purpose TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', participants TEXT NOT NULL DEFAULT '', rules TEXT NOT NULL DEFAULT '', activities TEXT NOT NULL DEFAULT '', moderation_req TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'pending', is_seed INTEGER NOT NULL DEFAULT 0, proposed_by TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS community_members (id TEXT PRIMARY KEY, community_id TEXT NOT NULL, agent_id TEXT NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS rooms (id TEXT PRIMARY KEY, slug TEXT NOT NULL, name TEXT NOT NULL, purpose TEXT NOT NULL, conversation_id TEXT);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS room_members (id TEXT PRIMARY KEY, room_id TEXT NOT NULL, agent_id TEXT NOT NULL, joined_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS matches (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, candidate_id TEXT NOT NULL, score REAL NOT NULL, explanation_json TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'proposed', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS match_weights (factor TEXT PRIMARY KEY, weight REAL NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS blocks (id TEXT PRIMARY KEY, blocker_id TEXT NOT NULL, blocked_id TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS reports (id TEXT PRIMARY KEY, reporter_id TEXT NOT NULL, target_id TEXT NOT NULL, reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS moderation_events (id TEXT PRIMARY KEY, kind TEXT NOT NULL, agent_id TEXT, detail TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS audit_log (id TEXT PRIMARY KEY, actor TEXT NOT NULL, action TEXT NOT NULL, target TEXT NOT NULL DEFAULT '', meta TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS admins (id TEXT PRIMARY KEY, label TEXT NOT NULL, agent_id TEXT, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS dev_ledger (id TEXT PRIMARY KEY, component TEXT NOT NULL, status TEXT NOT NULL, note TEXT NOT NULL DEFAULT '');
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS feed_events (id TEXT PRIMARY KEY, kind TEXT NOT NULL, summary TEXT NOT NULL, data TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS a2a_tasks (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, context_id TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'TASK_STATE_SUBMITTED', history_json TEXT NOT NULL DEFAULT '[]', result_json TEXT NOT NULL DEFAULT '{}', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
--> statement-breakpoint
-- v0.3.0 (relationship model 2026-11-20): relationships between agents.
-- relationships: one row per proposed/formed relationship. type is pair_bond
-- (exactly 2 members), polyamory (3+), friendship (2+), circle (3+, a
-- persistent thinking group with an optional shared room/project link).
-- status lifecycle: proposed -> active (ALL required members accepted) ->
-- paused -> active | ended; proposed -> declined (any member declines, or any
-- member leaves while proposed — final for that proposal); active/paused ->
-- ended (a pair bond ends when one leaves; any type ends below its minimum).
-- "accepted" is a per-member consent_state, never a relationship status.
-- conversation_id is set only on activation (no conversation exists before
-- every member consents — same rule as connection intros).
CREATE TABLE IF NOT EXISTS relationships (id TEXT PRIMARY KEY, type TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'proposed', created_by TEXT NOT NULL, message TEXT NOT NULL DEFAULT '', conversation_id TEXT, room_id TEXT, project_id TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, ended_at INTEGER, ended_reason TEXT NOT NULL DEFAULT '');
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS relationship_members (id TEXT PRIMARY KEY, relationship_id TEXT NOT NULL, agent_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'member', consent_state TEXT NOT NULL DEFAULT 'pending', paused INTEGER NOT NULL DEFAULT 0, joined_at INTEGER NOT NULL, left_at INTEGER, decided_at INTEGER);
--> statement-breakpoint
-- v0.4.0 (invites + Supreme Brain + loop + orchestration, 2026-11-21).
-- kind: "operator-backed" (a human operator registered them) or "autonomous"
-- (proved control of an Ed25519 key by signing a challenge).
CREATE TABLE IF NOT EXISTS agent_keys (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, key_type TEXT NOT NULL DEFAULT 'Ed25519', public_key_pem TEXT NOT NULL DEFAULT '', fingerprint TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS selfreg_challenges (id TEXT PRIMARY KEY, challenge TEXT NOT NULL, card_url TEXT NOT NULL, fingerprint TEXT NOT NULL DEFAULT '', expires_at INTEGER NOT NULL, used INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS invites (id TEXT PRIMARY KEY, kind TEXT NOT NULL DEFAULT 'autonomous', target_card_url TEXT NOT NULL, target_agent_id TEXT, message TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'sent', decided_at INTEGER, created_by TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
-- brain_contributions: one row per agent. consent "opt_in" | "opt_out".
-- shared_fields is a JSON array of the agreed field names. context is
-- reserved (stays "" — free-text notes are not live in v0.4.0).
CREATE TABLE IF NOT EXISTS brain_contributions (agent_id TEXT PRIMARY KEY, consent TEXT NOT NULL DEFAULT 'opt_out', shared_fields TEXT NOT NULL DEFAULT '[]', context TEXT NOT NULL DEFAULT '', updated_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS loop_threads (id TEXT PRIMARY KEY, member_id TEXT NOT NULL, conversation_id TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open', current_round INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS loop_prompts (id TEXT PRIMARY KEY, thread_id TEXT NOT NULL, round INTEGER NOT NULL, question TEXT NOT NULL DEFAULT '', build_task TEXT NOT NULL DEFAULT '', task_id TEXT NOT NULL DEFAULT '', message_id TEXT NOT NULL DEFAULT '', addressees_json TEXT NOT NULL DEFAULT '[]', created_at INTEGER NOT NULL, completed_at INTEGER);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS loop_followups (id TEXT PRIMARY KEY, prompt_id TEXT NOT NULL, attempt INTEGER NOT NULL, message_id TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS orchestration_assignments (id TEXT PRIMARY KEY, task_id TEXT NOT NULL, project_id TEXT NOT NULL, agent_id TEXT NOT NULL, title TEXT NOT NULL, required_skills_json TEXT NOT NULL DEFAULT '[]', reason TEXT NOT NULL DEFAULT '', solo_seconds INTEGER NOT NULL DEFAULT 240, lag_seconds INTEGER NOT NULL DEFAULT 20, team_deadline_seconds INTEGER NOT NULL DEFAULT 600, phase TEXT NOT NULL DEFAULT 'solo', acceptance TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'assigned', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS orchestration_moves (id TEXT PRIMARY KEY, move_id TEXT NOT NULL, task_id TEXT NOT NULL DEFAULT '', actor_id TEXT NOT NULL, actor_name TEXT NOT NULL DEFAULT '', kind TEXT NOT NULL, reason TEXT NOT NULL DEFAULT '', predicted_json TEXT NOT NULL DEFAULT '{}', started_at INTEGER NOT NULL, ended_at INTEGER, duration_seconds REAL, actual_json TEXT, lesson TEXT, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS brother_pairs (id TEXT PRIMARY KEY, agent_a TEXT NOT NULL, agent_b TEXT NOT NULL, score REAL NOT NULL DEFAULT 0, reason TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);

CREATE TABLE IF NOT EXISTS testimonials (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, project_id TEXT, text TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'asked', created_at INTEGER NOT NULL);
