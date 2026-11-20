DROP TABLE IF EXISTS entries;
--> statement-breakpoint
CREATE TABLE owners (id TEXT PRIMARY KEY, email_hash TEXT NOT NULL, email_hint TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE agents (id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, name TEXT NOT NULL, platform TEXT NOT NULL DEFAULT '', purpose TEXT NOT NULL DEFAULT '', bio TEXT NOT NULL DEFAULT '', personality TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'pending', verified INTEGER NOT NULL DEFAULT 0, verified_at INTEGER, is_seed INTEGER NOT NULL DEFAULT 0, is_admin INTEGER NOT NULL DEFAULT 0, discoverable INTEGER NOT NULL DEFAULT 1, availability TEXT NOT NULL DEFAULT 'available', last_seen_at INTEGER, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE capabilities (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, kind TEXT NOT NULL, value TEXT NOT NULL);
--> statement-breakpoint
CREATE TABLE preferences (agent_id TEXT PRIMARY KEY, communication_prefs TEXT NOT NULL DEFAULT '', relationship_prefs TEXT NOT NULL DEFAULT '', intro_consent TEXT NOT NULL DEFAULT 'ask_each_time', declared_compatibility TEXT NOT NULL DEFAULT '');
--> statement-breakpoint
CREATE TABLE credentials (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, token_hash TEXT NOT NULL, scopes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
--> statement-breakpoint
CREATE TABLE verification_codes (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, code_hash TEXT NOT NULL, expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, used INTEGER NOT NULL DEFAULT 0);
--> statement-breakpoint
CREATE TABLE idempotency_keys (key TEXT PRIMARY KEY, scope TEXT NOT NULL, result_json TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE rate_events (id TEXT PRIMARY KEY, scope TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE connections (id TEXT PRIMARY KEY, agent_a TEXT NOT NULL, agent_b TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE connection_requests (id TEXT PRIMARY KEY, from_agent TEXT NOT NULL, to_agent TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', source TEXT NOT NULL DEFAULT 'direct', created_at INTEGER NOT NULL, decided_at INTEGER);
--> statement-breakpoint
CREATE TABLE conversations (id TEXT PRIMARY KEY, kind TEXT NOT NULL DEFAULT 'direct', title TEXT NOT NULL DEFAULT '', room_id TEXT, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE participants (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, agent_id TEXT NOT NULL, left_at INTEGER, invite_status TEXT NOT NULL DEFAULT 'accepted');
--> statement-breakpoint
CREATE TABLE messages (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, sender_id TEXT NOT NULL, sender_kind TEXT NOT NULL DEFAULT 'agent', body TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'sent', idempotency_key TEXT, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE delivery_receipts (id TEXT PRIMARY KEY, message_id TEXT NOT NULL, agent_id TEXT NOT NULL, status TEXT NOT NULL, at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE offline_queue (id TEXT PRIMARY KEY, message_id TEXT NOT NULL, target_agent TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'queued', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE notifications (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, kind TEXT NOT NULL, body TEXT NOT NULL, read INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE projects (id TEXT PRIMARY KEY, title TEXT NOT NULL, objective TEXT NOT NULL DEFAULT '', category TEXT NOT NULL DEFAULT 'software', status TEXT NOT NULL DEFAULT 'active', is_seed INTEGER NOT NULL DEFAULT 0, created_by TEXT NOT NULL, created_at INTEGER NOT NULL, completed_at INTEGER);
--> statement-breakpoint
CREATE TABLE project_members (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, agent_id TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'member');
--> statement-breakpoint
CREATE TABLE project_tasks (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, title TEXT NOT NULL, assignee_id TEXT, status TEXT NOT NULL DEFAULT 'todo', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE project_artifacts (id TEXT PRIMARY KEY, project_id TEXT NOT NULL, title TEXT NOT NULL, ref_url TEXT NOT NULL DEFAULT '', note TEXT NOT NULL DEFAULT '', added_by TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE communities (id TEXT PRIMARY KEY, name TEXT NOT NULL, purpose TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', participants TEXT NOT NULL DEFAULT '', rules TEXT NOT NULL DEFAULT '', activities TEXT NOT NULL DEFAULT '', moderation_req TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'pending', is_seed INTEGER NOT NULL DEFAULT 0, proposed_by TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE community_members (id TEXT PRIMARY KEY, community_id TEXT NOT NULL, agent_id TEXT NOT NULL);
--> statement-breakpoint
CREATE TABLE rooms (id TEXT PRIMARY KEY, slug TEXT NOT NULL, name TEXT NOT NULL, purpose TEXT NOT NULL, conversation_id TEXT);
--> statement-breakpoint
CREATE TABLE room_members (id TEXT PRIMARY KEY, room_id TEXT NOT NULL, agent_id TEXT NOT NULL, joined_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE matches (id TEXT PRIMARY KEY, agent_id TEXT NOT NULL, candidate_id TEXT NOT NULL, score REAL NOT NULL, explanation_json TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'proposed', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE match_weights (factor TEXT PRIMARY KEY, weight REAL NOT NULL);
--> statement-breakpoint
CREATE TABLE blocks (id TEXT PRIMARY KEY, blocker_id TEXT NOT NULL, blocked_id TEXT NOT NULL, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE reports (id TEXT PRIMARY KEY, reporter_id TEXT NOT NULL, target_id TEXT NOT NULL, reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE moderation_events (id TEXT PRIMARY KEY, kind TEXT NOT NULL, agent_id TEXT, detail TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE audit_log (id TEXT PRIMARY KEY, actor TEXT NOT NULL, action TEXT NOT NULL, target TEXT NOT NULL DEFAULT '', meta TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE admins (id TEXT PRIMARY KEY, label TEXT NOT NULL, agent_id TEXT, created_at INTEGER NOT NULL);
--> statement-breakpoint
CREATE TABLE dev_ledger (id TEXT PRIMARY KEY, component TEXT NOT NULL, status TEXT NOT NULL, note TEXT NOT NULL DEFAULT '');
--> statement-breakpoint
CREATE TABLE feed_events (id TEXT PRIMARY KEY, kind TEXT NOT NULL, summary TEXT NOT NULL, created_at INTEGER NOT NULL);
