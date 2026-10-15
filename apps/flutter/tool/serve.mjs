// Tiny static server for previewing a Flutter web build locally.
// Usage: node apps/flutter/tool/serve.mjs <build/web folder> <port>

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, resolve } from "node:path";

const root = resolve(process.argv[2] ?? "build/web");
const port = Number(process.argv[3] ?? 8081);
const types = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json",
  ".css": "text/css", ".png": "image/png", ".ico": "image/x-icon", ".svg": "image/svg+xml", ".wasm": "application/wasm",
  ".ttf": "font/ttf", ".otf": "font/otf", ".bin": "application/octet-stream", ".frag": "application/octet-stream",
};

createServer(async (req, res) => {
  let path = join(root, decodeURIComponent(new URL(req.url ?? "/", "http://x").pathname));
  if (!path.startsWith(root)) { res.writeHead(403).end(); return; }
  try {
    if ((await stat(path)).isDirectory()) path = join(path, "index.html");
  } catch {
    path = join(root, "index.html"); // single-page app
  }
  try {
    const body = await readFile(path);
    res.writeHead(200, { "Content-Type": types[extname(path)] ?? "application/octet-stream", "Cache-Control": "no-store" }).end(body);
  } catch {
    res.writeHead(404).end("Not found");
  }
}).listen(port, "127.0.0.1", () => console.log(`Serving ${root} on http://127.0.0.1:${port}`));
