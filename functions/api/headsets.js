const json = (value, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
});

const columns = `id, asset_tag, brand, model, serial_number, status, assigned_to, department, notes, created_at`;

export async function onRequestGet({ env }) {
  const { results } = await env.DB.prepare(`SELECT ${columns} FROM headsets ORDER BY created_at DESC`).all();
  return json(results);
}

export async function onRequestPost({ request, env }) {
  let asset;
  try { asset = await request.json(); } catch { return json({ error: "Invalid JSON body" }, 400); }
  if (!asset.id || !asset.asset_tag || !asset.brand || !asset.model) {
    return json({ error: "id, asset_tag, brand, and model are required" }, 400);
  }
  try {
    await env.DB.prepare(`INSERT INTO headsets (${columns}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(String(asset.id), String(asset.asset_tag), String(asset.brand), String(asset.model),
        String(asset.serial_number ?? ""), String(asset.status ?? "Available"), String(asset.assigned_to ?? ""),
        String(asset.department ?? ""), String(asset.notes ?? ""), String(asset.created_at ?? new Date().toISOString()))
      .run();
    return json({ ok: true }, 201);
  } catch (error) {
    return json({ error: error.message || "Could not save headset" }, 409);
  }
}

export async function onRequestPut({ request, env }) {
  let asset;
  try { asset = await request.json(); } catch { return json({ error: "Invalid JSON body" }, 400); }
  if (!asset.id || !asset.asset_tag || !asset.brand || !asset.model) {
    return json({ error: "id, asset_tag, brand, and model are required" }, 400);
  }
  const result = await env.DB.prepare(`UPDATE headsets SET asset_tag=?, brand=?, model=?, serial_number=?, status=?, assigned_to=?, department=?, notes=?, created_at=? WHERE id=?`)
    .bind(String(asset.asset_tag), String(asset.brand), String(asset.model), String(asset.serial_number ?? ""),
      String(asset.status ?? "Available"), String(asset.assigned_to ?? ""), String(asset.department ?? ""),
      String(asset.notes ?? ""), String(asset.created_at ?? new Date().toISOString()), String(asset.id)).run();
  return result.meta.changes ? json({ ok: true }) : json({ error: "Headset not found" }, 404);
}

export async function onRequestDelete({ request, env }) {
  let asset;
  try { asset = await request.json(); } catch { return json({ error: "Invalid JSON body" }, 400); }
  if (!asset.id) return json({ error: "id is required" }, 400);
  const result = await env.DB.prepare("DELETE FROM headsets WHERE id=?").bind(String(asset.id)).run();
  return json({ ok: true, deleted: result.meta.changes });
}
