// Shared FCM HTTP v1 helper for edge functions.
// Replaces the legacy https://fcm.googleapis.com/fcm/send API (shut down by Google).
//
// Required secret: FCM_SERVICE_ACCOUNT_JSON  (full service-account key JSON, as a string)
//   supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedToken: { value: string; expiresAt: number } | null = null;
let cachedSa: ServiceAccount | null = null;

function getServiceAccount(): ServiceAccount {
  if (cachedSa) return cachedSa;
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT_JSON secret is not set");
  cachedSa = JSON.parse(raw) as ServiceAccount;
  return cachedSa;
}

function b64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const sa = getServiceAccount();
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${b64url(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const json = await res.json();
  if (!res.ok || !json.access_token) {
    throw new Error(`OAuth token exchange failed: ${JSON.stringify(json)}`);
  }
  cachedToken = { value: json.access_token, expiresAt: now + (json.expires_in ?? 3600) };
  return cachedToken.value;
}

export interface FcmMessage {
  token?: string;
  topic?: string;
  title: string;
  body: string;
  /** All values are coerced to strings (FCM v1 requires string-only data). */
  data?: Record<string, unknown>;
  androidChannelId?: string;
  /** "high" for time-critical pushes. */
  priority?: "high" | "normal";
  sound?: string;
}

export interface FcmResult {
  ok: boolean;
  status: number;
  /** FCM error code, e.g. UNREGISTERED, INVALID_ARGUMENT. */
  errorCode?: string;
  raw: unknown;
}

export async function sendFcm(msg: FcmMessage): Promise<FcmResult> {
  if (!msg.token && !msg.topic) throw new Error("sendFcm needs a token or topic");
  const sa = getServiceAccount();
  const accessToken = await getAccessToken();

  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries(msg.data ?? {})) data[k] = String(v ?? "");

  const priority = msg.priority ?? "high";
  const message: Record<string, unknown> = {
    notification: { title: msg.title, body: msg.body },
    data,
    android: {
      priority: priority === "high" ? "HIGH" : "NORMAL",
      notification: {
        ...(msg.androidChannelId ? { channel_id: msg.androidChannelId } : {}),
        ...(msg.sound ? { sound: msg.sound } : {}),
        color: "#D32F2F",
      },
    },
    apns: {
      headers: { "apns-priority": priority === "high" ? "10" : "5" },
      payload: { aps: { sound: msg.sound ?? "default" } },
    },
  };
  if (msg.token) message.token = msg.token;
  else message.topic = msg.topic;

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ message }),
    },
  );
  const raw = await res.json().catch(() => ({}));
  if (res.ok) return { ok: true, status: res.status, raw };

  const details = (raw as any)?.error?.details ?? [];
  const fcmCode = details.find((d: any) => d?.errorCode)?.errorCode;
  return {
    ok: false,
    status: res.status,
    errorCode: fcmCode ?? (raw as any)?.error?.status,
    raw,
  };
}

/** True when the token is permanently dead and should be cleared. */
export function isDeadToken(r: FcmResult): boolean {
  return r.errorCode === "UNREGISTERED" || r.errorCode === "NOT_FOUND";
}
