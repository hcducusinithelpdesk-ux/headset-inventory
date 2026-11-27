const json = (value, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
});

const fromBase64 = value => Uint8Array.from(atob(value), character => character.charCodeAt(0));
const toBase64 = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes)));

async function passwordHash(password, salt) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations: 120000, hash: "SHA-256" }, key, 256);
  return toBase64(bits);
}

export async function onRequestPost({ request, env }) {
  let input;
  try { input = await request.json(); } catch { return json({ error: "Invalid request" }, 400); }
  const username = String(input.username ?? "").trim();
  const password = String(input.password ?? "");
  if (!username || !password) return json({ error: "Username and password are required" }, 400);

  if (username.toLowerCase() === "administrator" && env.ADMIN_PASSWORD && password === env.ADMIN_PASSWORD) {
    return json({ username: "administrator", role: "admin" });
  }

  const row = await env.DB.prepare("SELECT username, salt, password_hash FROM viewer_users WHERE username = ? COLLATE NOCASE")
    .bind(username).first();
  if (!row) return json({ error: "Invalid username or password" }, 401);
  const actual = await passwordHash(password, fromBase64(row.salt));
  if (actual !== row.password_hash) return json({ error: "Invalid username or password" }, 401);
  return json({ username: row.username, role: "viewer" });
}
