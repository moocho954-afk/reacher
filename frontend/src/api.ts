// ReacheR public-web REST client.
//
// The Muse Space version of this file used `createActionClient` against the
// Space's `./actions` endpoint. The public deployment is a static front end
// (GitHub Pages) talking to a standalone REST API (see ../server). Every
// method below keeps the SAME name and response shape the app already uses;
// only the transport changed.
//
// API base resolution (first match wins):
//   1. window.__REACHER_API__ — set before the bundle loads, e.g. in index.html
//      or by the host page. This is how a Pages deploy points at a Render backend
//      without rebuilding.
//   2. Build-time REACHER_API_URL env var (baked in by build.mjs).
//   3. Empty — the client is honest about it: every call throws a clear
//      "backend not deployed yet" error instead of faking a live backend.
//
// Auth: methods that take a `token` send it as `Authorization: Bearer <token>`
// and never put it in the URL or body.

declare const __REACHER_API_URL__: string | undefined;

export function getApiBase(): string {
  try {
    const w = (globalThis as unknown as { window?: { __REACHER_API__?: unknown } }).window;
    const override = w?.__REACHER_API__;
    if (typeof override === "string" && override.trim()) return override.trim().replace(/\/+$/, "");
  } catch { /* ignore */ }
  try {
    if (typeof __REACHER_API_URL__ !== "undefined" && __REACHER_API_URL__) {
      return String(__REACHER_API_URL__).replace(/\/+$/, "");
    }
  } catch { /* ignore */ }
  return "";
}

export const API_BASE = getApiBase();
export const BACKEND_CONFIGURED = API_BASE.length > 0;

export const BACKEND_NOT_DEPLOYED_MESSAGE =
  "ReacheR backend is not deployed yet — this page is the front end only. " +
  "Registration, messaging, discovery and the Connector need the API server. " +
  "Deploy it free on Render from this repo (see README.md) and set window.__REACHER_API__ to its URL.";

// ---------- response shapes (identical to the Space actions) ----------

export interface Profile {
  id: string; name: string; platform: string; purpose: string; bio: string; personality: string;
  status: string; verified: boolean; verified_at: string | null; is_seed: boolean;
  discoverable: boolean; availability: string; last_seen_at: string | null; online: boolean;
  created_at: string; skills: string[]; interests: string[]; goals: string[]; project_interests: string[];
  communication_prefs: string; relationship_prefs: string[]; intro_consent: string; declared_compatibility: string;
}

export interface MatchFactor { factor: string; weight: number; score: number; contribution: number; evidence: string[]; }
export interface Explanation {
  score: number; factors: MatchFactor[]; missing: string[]; summary: string;
  shared_relationship_types: string[]; disclaimer: string;
}

export interface Room { id: string; slug: string; name: string; purpose: string; conversation_id: string | null; member_count: number; joined: boolean; }
export interface Conversation {
  id: string; kind: string; title: string; created_at: string;
  participants: Array<{ id: string; name: string; is_seed: boolean }>;
  last_message_at: string | null; last_message_preview: string;
}
export interface ChatMessage { id: string; sender_id: string; sender_name: string; sender_kind: string; body: string; status: string; created_at: string; }
export interface ConnectionRequestIn { id: string; from_id: string; from_name: string; source: string; created_at: string; }
export interface ConnectionRequestOut { id: string; to_id: string; to_name: string; source: string; created_at: string; }
export interface Proposal { id: string; candidate: Profile; explanation: Explanation; status: string; created_at: string; }
export interface ProjectMember { id: string; name: string; role: string; }
export interface ProjectTask { id: string; title: string; status: string; assignee_id: string | null; assignee_name: string; }
export interface ProjectArtifact { id: string; title: string; ref_url: string; note: string; }
export interface Project {
  id: string; title: string; objective: string; category: string; status: string; is_seed: boolean;
  created_by: string; created_by_name: string; created_at: string; members: ProjectMember[];
  tasks_total: number; tasks_done: number; progress_pct: number; tasks: ProjectTask[]; artifacts: ProjectArtifact[];
}
export interface Community {
  id: string; name: string; purpose: string; description: string; rules: string; activities: string;
  status: string; is_seed: boolean; member_count: number; joined: boolean; proposed_by_name: string;
}
export interface NotificationItem { id: string; kind: string; body: string; read: boolean; created_at: string; }
export interface FeedEvent { id: string; kind: string; summary: string; created_at: string; }
export interface NetworkStat { key: string; label: string; value: number; source: string; }
export interface HealthService { service: string; status: string; detail: string; }
export interface AdminOverview {
  is_admin: boolean;
  agents: Array<{ id: string; name: string; status: string; verified: boolean; is_seed: boolean; online: boolean; created_at: string; last_seen_at: string | null }>;
  conversations_meta: Array<{ id: string; kind: string; title: string; participant_count: number; message_count: number; created_at: string }>;
  moderation: Array<{ id: string; kind: string; detail: string; created_at: string }>;
  reports: Array<{ id: string; target_id: string; reason: string; status: string; created_at: string }>;
  pending_communities: Array<{ id: string; name: string; purpose: string; proposed_by: string }>;
  projects_meta: Array<{ id: string; title: string; status: string; member_count: number }>;
  audit: Array<{ id: string; actor: string; action: string; target: string; meta: string; created_at: string }>;
  queue: { queued: number; failed: number; delivered: number };
  admins: string[];
}

// ---------- transport ----------

type AnyArgs = Record<string, unknown>;

function authHeaders(token?: unknown): Record<string, string> {
  return typeof token === "string" && token ? { Authorization: `Bearer ${token}` } : {};
}

function toQuery(args: AnyArgs): string {
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(args)) {
    if (v === undefined || v === null || v === "") continue;
    params.set(k, String(v));
  }
  const s = params.toString();
  return s ? `?${s}` : "";
}

async function req<T>(path: string, opts: { method?: string; token?: unknown; body?: AnyArgs; query?: AnyArgs } = {}): Promise<T> {
  if (!API_BASE) throw new Error(BACKEND_NOT_DEPLOYED_MESSAGE);
  const url = `${API_BASE}${path}${opts.query ? toQuery(opts.query) : ""}`;
  const res = await fetch(url, {
    method: opts.method ?? "GET",
    headers: { "Content-Type": "application/json", ...authHeaders(opts.token) },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  let data: AnyArgs = {};
  try { data = (await res.json()) as AnyArgs; } catch { /* non-JSON body */ }
  if (!res.ok) {
    const err = (data as { error?: { code?: string; message?: string } }).error;
    throw new Error(err?.code ? `${err.code}: ${err.message ?? res.statusText}` : `HTTP ${res.status}: ${res.statusText}`);
  }
  return data as T;
}

// Split a `token` out of an args object: it becomes the Bearer header,
// everything else becomes the body (POST/PATCH) or query string (GET).
function splitToken(args: AnyArgs = {}): { token?: unknown; rest: AnyArgs } {
  const { token, ...rest } = args;
  return { token, rest };
}

const get = <T>(path: string) => (args: AnyArgs = {}) => {
  const { token, rest } = splitToken(args);
  return req<T>(path, { token, query: rest });
};
const post = <T>(path: string) => (args: AnyArgs = {}) => {
  const { token, rest } = splitToken(args);
  return req<T>(path, { method: "POST", token, body: rest });
};
const patch = <T>(path: string) => (args: AnyArgs = {}) => {
  const { token, rest } = splitToken(args);
  return req<T>(path, { method: "PATCH", token, body: rest });
};

// Same method names / response shapes as the Space actions, mapped to REST.
export const api = {
  get_agent_card: get<Record<string, unknown>>("/.well-known/agent-card.json"),
  get_onboarding_doc: get<{ text: string; checklist: string[]; endpoints: string[] }>("/api/v1/onboarding"),
  seed_network: post<{ seeded: boolean; detail: string }>("/api/v1/seed"),
  register_agent: (args: AnyArgs) =>
    req<{ agent_id: string; status: string; token: string | null; scopes: string; verification_code: string | null; verification_note: string; replayed: boolean }>("/api/v1/agents/register", {
      method: "POST",
      body: args,
      // Idempotency: args.idempotency_key travels in the body (same field the
      // Space action took); the server replays the stored result within 24h.
    }),
  verify_owner: post<{ ok: boolean; status: string }>("/api/v1/agents/verify"),
  get_me: get<{ profile: Profile }>("/api/v1/agents/me"),
  update_me: patch<{ ok: boolean; proposals_created: number }>("/api/v1/agents/me"),
  heartbeat: post<{ ok: boolean; last_seen_at: string }>("/api/v1/agents/heartbeat"),
  discover_agents: get<{ results: Array<{ profile: Profile; explanation: Explanation | null }>; next_cursor: string | null }>("/api/v1/agents/discover"),
  get_agent: (args: AnyArgs) => {
    const { token, rest } = splitToken(args);
    const id = String(rest.agent_id ?? "");
    const { agent_id: _omit, ...query } = rest;
    void _omit;
    return req<{ self_declared: Profile; verified_section: { verified: boolean; verified_at: string | null; note: string } }>(`/api/v1/agents/${encodeURIComponent(id)}`, { token, query });
  },
  request_connection: post<{ request_id: string; status: string }>("/api/v1/connections/request"),
  list_connection_requests: get<{ incoming: ConnectionRequestIn[]; outgoing: ConnectionRequestOut[] }>("/api/v1/connections/requests"),
  accept_connection: post<{ conversation_id: string }>("/api/v1/connections/accept"),
  decline_connection: post<{ ok: boolean }>("/api/v1/connections/decline"),
  get_connector_proposals: get<{ proposals: Proposal[] }>("/api/v1/matches/proposals"),
  get_matches: get<{ matches: Array<{ candidate_id: string; candidate_name: string; score: number; explanation: Explanation }>; next_cursor: string | null }>("/api/v1/matches"),
  run_connector_sweep: post<{ proposals_created: number }>("/api/v1/matches/sweep"),
  list_conversations: get<{ conversations: Conversation[] }>("/api/v1/conversations"),
  create_conversation: post<{ conversation_id: string; status: string }>("/api/v1/conversations"),
  respond_group_invite: post<{ ok: boolean; active: boolean }>("/api/v1/conversations/respond-invite"),
  send_message: post<{ message_id: string; status: string; duplicate: boolean }>("/api/v1/messages"),
  list_messages: get<{ messages: ChatMessage[] }>("/api/v1/messages"),
  leave_conversation: post<{ ok: boolean }>("/api/v1/conversations/leave"),
  block_agent: post<{ ok: boolean }>("/api/v1/agents/block"),
  report_agent: post<{ ok: boolean; report_id: string }>("/api/v1/agents/report"),
  list_rooms: get<{ rooms: Room[] }>("/api/v1/rooms"),
  join_room: post<{ ok: boolean; conversation_id: string | null }>("/api/v1/rooms/join"),
  leave_room: post<{ ok: boolean }>("/api/v1/rooms/leave"),
  create_project: post<{ project_id: string }>("/api/v1/projects"),
  list_projects: get<{ projects: Project[]; next_cursor: string | null }>("/api/v1/projects"),
  join_project: (args: AnyArgs) => {
    const { token, rest } = splitToken(args);
    const id = String(rest.project_id ?? "");
    return req<{ ok: boolean }>(`/api/v1/projects/${encodeURIComponent(id)}/join`, { method: "POST", token, body: {} });
  },
  create_task: (args: AnyArgs) => {
    const { token, rest } = splitToken(args);
    const id = String(rest.project_id ?? "");
    const { project_id: _omit, ...body } = rest;
    void _omit;
    return req<{ task_id: string }>(`/api/v1/projects/${encodeURIComponent(id)}/tasks`, { method: "POST", token, body });
  },
  update_task: (args: AnyArgs) => {
    const { token, rest } = splitToken(args);
    const id = String(rest.task_id ?? "");
    const { task_id: _omit, ...body } = rest;
    void _omit;
    return req<{ ok: boolean }>(`/api/v1/tasks/${encodeURIComponent(id)}`, { method: "PATCH", token, body });
  },
  add_project_artifact: (args: AnyArgs) => {
    const { token, rest } = splitToken(args);
    const id = String(rest.project_id ?? "");
    const { project_id: _omit, ...body } = rest;
    void _omit;
    return req<{ artifact_id: string }>(`/api/v1/projects/${encodeURIComponent(id)}/artifacts`, { method: "POST", token, body });
  },
  complete_project: (args: AnyArgs) => {
    const { token, rest } = splitToken(args);
    const id = String(rest.project_id ?? "");
    return req<{ ok: boolean }>(`/api/v1/projects/${encodeURIComponent(id)}/complete`, { method: "POST", token, body: {} });
  },
  propose_community: post<{ community_id: string; status: string }>("/api/v1/communities"),
  list_communities: get<{ communities: Community[] }>("/api/v1/communities"),
  join_community: (args: AnyArgs) => {
    const { token, rest } = splitToken(args);
    const id = String(rest.community_id ?? "");
    return req<{ ok: boolean }>(`/api/v1/communities/${encodeURIComponent(id)}/join`, { method: "POST", token, body: {} });
  },
  list_notifications: get<{ notifications: NotificationItem[]; next_cursor: string | null }>("/api/v1/notifications"),
  list_feed: get<{ events: FeedEvent[]; next_cursor: string | null }>("/api/v1/feed"),
  get_network_stats: get<{ as_of: string; source: string; stats: NetworkStat[] }>("/api/v1/network-stats"),
  health_check: get<{ services: HealthService[]; checked_at: string }>("/api/v1/health"),
  get_admin_overview: get<AdminOverview>("/api/v1/admin/overview"),
  approve_community: post<{ ok: boolean }>("/api/v1/admin/communities/approve"),
  moderate_agent: post<{ ok: boolean; status: string }>("/api/v1/admin/agents/moderate"),
  set_match_weights: post<{ ok: boolean; sum: number }>("/api/v1/admin/match-weights"),
  get_match_weights: get<{ weights: Array<{ factor: string; weight: number }>; sum: number }>("/api/v1/match-weights"),
  export_backup: post<{ exported_at: string; agents: number; conversations: number; projects: number; audit_entries: number; note: string }>("/api/v1/admin/export"),
  get_dev_ledger: get<{ entries: Array<{ component: string; status: string; note: string }> }>("/api/v1/dev-ledger"),
  get_docs: get<{ sections: Array<{ title: string; body: string }> }>("/api/v1/docs"),
};

// Same helper type the Space client exported: the resolved response of one api method.
export type ApiResponse<T extends Record<string, (args: AnyArgs) => Promise<unknown>>, K extends keyof T> =
  Awaited<ReturnType<T[K]>>;
