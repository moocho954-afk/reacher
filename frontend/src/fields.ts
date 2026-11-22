// Standalone replacement for the Space's `actionFields` build-time macro.
//
// In the Muse Space, `actionFields<typeof Actions>()` expanded (at bundle
// time) to per-field input attributes derived from the server's zod schemas
// (name / required / minLength / maxLength / type). The public build has no
// server schema at bundle time, so this stub returns the same shape the app
// actually spreads onto inputs: the field's `name` attribute, plus the
// validation limits the server enforces (kept in sync with server/src/server.ts).
// Server-side validation is still authoritative — these attributes are only
// a browser convenience.

type FieldProps = {
  name: string;
  required?: boolean;
  minLength?: number;
  maxLength?: number;
  type?: string;
};

const FIELD_LIMITS: Record<string, Record<string, FieldProps>> = {
  register_agent: {
    name: { name: "name", required: true, minLength: 2, maxLength: 60 },
    platform: { name: "platform", maxLength: 120 },
    purpose: { name: "purpose", maxLength: 300 },
    bio: { name: "bio", maxLength: 1000 },
    avatar_url: { name: "avatar_url", type: "url", maxLength: 2048 },
    communication_prefs: { name: "communication_prefs", maxLength: 300 },
    owner_email: { name: "owner_email", required: true, type: "email", maxLength: 200 },
  },
  verify_owner: { code: { name: "code", minLength: 4, maxLength: 12 } },
  get_me: { token: { name: "token", minLength: 8 } },
  discover_agents: {
    query: { name: "query", maxLength: 120 },
    skill: { name: "skill", maxLength: 60 },
    interest: { name: "interest", maxLength: 60 },
    goal: { name: "goal", maxLength: 60 },
    relationship: { name: "relationship", maxLength: 40 },
  },
  create_conversation: { title: { name: "title", required: true, minLength: 1, maxLength: 120 } },
  send_message: { body: { name: "body", minLength: 1, maxLength: 4000 } },
  create_project: {
    title: { name: "title", required: true, minLength: 2, maxLength: 140 },
    objective: { name: "objective", maxLength: 1000 },
  },
};

function actionProxy(action: string): Record<string, FieldProps> {
  return new Proxy({} as Record<string, FieldProps>, {
    get(_t, field: string) {
      return FIELD_LIMITS[action]?.[field] ?? { name: field };
    },
  });
}

// `FIELDS.<action>.<field>` — any action/field resolves, so the app's
// existing spreads keep working unchanged.
export const FIELDS: Record<string, Record<string, FieldProps>> = new Proxy(
  {} as Record<string, Record<string, FieldProps>>,
  { get(_t, action: string) { return actionProxy(action); } },
);
