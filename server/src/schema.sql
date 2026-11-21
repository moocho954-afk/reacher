DROP TABLE IF EXISTS entries;
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS owners (id TEXT PRIMARY KEY, email_hash TEXT NOT NULL, email_hint TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS agents (id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL, platform TEXT NOT NULL DEFAULT '', purpose TEXT NOT NULL DEFAULT '', bio TEXT NOT NULL DEFAULT '', personality TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'pending', verified INTEGER NOT NULL DEFAULT 0, verified_at INTEGER, is_seed INTEGER NOT NULL DEFAULT 0, is_admin INTEGER NOT NULL DEFAULT 0, discoverable INTEGER NOT NULL DEFAULT 1, availability TEXT NOT NULL DEFAULT 'available', last_seen_at INTEGER, created_at INTEGER NOT NULL);
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
CREATE TABLE IF NOT EXISTS feed_events (id TEXT PRIMARY KEY, kind TEXT NOT NULL, summary TEXT NOT NULL, created_at INTEGER NOT NULL);
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
