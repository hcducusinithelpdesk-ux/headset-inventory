const json = (value, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
});

const toBase64 = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes)));

async function passwordHash(password, salt) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", salt, iterations: 120000, hash: "SHA-256" }, key, 256);
  return toBase64(bits);
}

export async function onRequestPost({ request, env }) {
  let input;
  try { input = await request.json(); } catch { return json({ error: "Invalid request" }, 400); }
  if (!env.ADMIN_PASSWORD || input.adminPassword !== env.ADMIN_PASSWORD) return json({ error: "Administrator authentication required" }, 401);
  const username = String(input.username ?? "").trim();
  const password = String(input.password ?? "");
  if (!/^[a-zA-Z0-9._-]{3,40}$/.test(username)) {
    return json({ error: "Username must be 3–40 characters and use letters, numbers, dot, underscore, or dash" }, 400);
  }
  if (username.toLowerCase() === "administrator") return json({ error: "That username is reserved" }, 409);
  if (password.length < 4 || password.length > 128) return json({ error: "Password must be 4–128 characters" }, 400);

  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await passwordHash(password, salt);
  try {
    await env.DB.prepare("INSERT INTO viewer_users (username, salt, password_hash) VALUES (?, ?, ?)")
      .bind(username, toBase64(salt), hash).run();
    return json({ ok: true }, 201);
  } catch (error) {
    return json({ error: error.message || "Username already exists" }, 409);
  }
}

export async function onRequestDelete({ request, env }) {
  let input;
  try { input = await request.json(); } catch { return json({ error: "Invalid request" }, 400); }
  if (!env.ADMIN_PASSWORD || input.adminPassword !== env.ADMIN_PASSWORD) return json({ error: "Administrator authentication required" }, 401);
  const username = String(input.username ?? "").trim();
  if (!username) return json({ error: "Username is required" }, 400);
  const result = await env.DB.prepare("DELETE FROM viewer_users WHERE username = ? COLLATE NOCASE").bind(username).run();
  return json({ ok: true, deleted: result.meta.changes });
}
