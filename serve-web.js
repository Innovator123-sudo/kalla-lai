#!/usr/bin/env node
/**
 * Local dev server for the Kalla-Lai web build.
 *
 * Serves build/web on port 7358 AND proxies /v1, /healthz and /readyz to the
 * API on 127.0.0.1:8090. That makes `http://127.0.0.1:7358` behave exactly
 * like the deployed site, where the API is served on the same origin, so the
 * same client code and the same same-origin `/v1` requests work in both.
 *
 * Usage: node serve-web.js [--port 7358] [--api 8090]
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 7358));
const API_PORT = Number(arg('api', 8090));
const ROOT = path.resolve(__dirname, 'build', 'web');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
};

const PROXY_PREFIXES = ['/v1', '/healthz', '/readyz', '/metrics'];

function proxy(req, res) {
  const options = {
    hostname: '127.0.0.1',
    port: API_PORT,
    path: req.url,
    method: req.method,
    headers: { ...req.headers, host: `127.0.0.1:${API_PORT}` },
  };
  const upstream = http.request(options, (up) => {
    res.writeHead(up.statusCode || 502, up.headers);
    up.pipe(res);
  });
  upstream.on('error', (e) => {
    res.writeHead(502, { 'content-type': 'application/json' });
    res.end(
      JSON.stringify({
        error: {
          code: 'UPSTREAM_UNAVAILABLE',
          message: `Cannot reach the API on 127.0.0.1:${API_PORT}. Start it with: cd server && npm run dev`,
        },
        detail: e.message,
      }),
    );
  });
  req.pipe(upstream);
}

function sendFile(res, filePath, req) {
  const ext = path.extname(filePath).toLowerCase();
  const type = MIME[ext] || 'application/octet-stream';
  const stat = fs.statSync(filePath);
  const headers = {
    'content-type': type,
    'accept-ranges': 'bytes',
    'cache-control': 'no-cache',
  };

  // Range support matters for <video> playback.
  const range = req.headers.range;
  if (range) {
    const m = /^bytes=(\d*)-(\d*)$/.exec(range.trim());
    if (m) {
      let start = m[1] === '' ? null : Number(m[1]);
      let end = m[2] === '' ? null : Number(m[2]);
      if (start === null && end !== null) {
        start = Math.max(0, stat.size - end);
        end = stat.size - 1;
      } else {
        if (start === null) start = 0;
        if (end === null || end >= stat.size) end = stat.size - 1;
      }
      if (start > end || start >= stat.size) {
        res.writeHead(416, { 'content-range': `bytes */${stat.size}` });
        res.end();
        return;
      }
      headers['content-range'] = `bytes ${start}-${end}/${stat.size}`;
      headers['content-length'] = end - start + 1;
      res.writeHead(206, headers);
      fs.createReadStream(filePath, { start, end }).pipe(res);
      return;
    }
  }

  headers['content-length'] = stat.size;
  res.writeHead(200, headers);
  fs.createReadStream(filePath).pipe(res);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const pathname = decodeURIComponent(url.pathname);

  if (PROXY_PREFIXES.some((p) => pathname === p || pathname.startsWith(p + '/'))) {
    proxy(req, res);
    return;
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: { code: 'METHOD_NOT_ALLOWED', message: 'Use GET.' } }));
    return;
  }

  // Resolve inside ROOT only.
  let filePath = path.join(ROOT, pathname);
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403).end('Forbidden');
    return;
  }

  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, 'index.html');
  }
  if (!fs.existsSync(filePath)) {
    // SPA fallback for client-side routes.
    const fallback = path.join(ROOT, 'index.html');
    if (fs.existsSync(fallback)) {
      sendFile(res, fallback, req);
    } else {
      res.writeHead(404, { 'content-type': 'text/plain' });
      res.end('Not found. Run "flutter build web --no-tree-shake-icons" first.');
    }
    return;
  }

  sendFile(res, filePath, req);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Kalla-Lai dev server`);
  console.log(`  web  http://127.0.0.1:${PORT}   (root: ${ROOT})`);
  console.log(`  api  http://127.0.0.1:${PORT}/v1 -> 127.0.0.1:${API_PORT}`);
});
