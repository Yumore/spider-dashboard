import http from 'node:http';
import net from 'node:net';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(toolDirectory, '..');
const frontend = path.join(root, 'build', 'web');
const port = Number(process.env.PORT || 43126);
const base = `http://127.0.0.1:${port}`;
const previewSource = (process.env.PREVIEW_SOURCE || 'https://huangguoai.com').replace(/\/+$/, '');
const devServerUrl = process.env.DEV_SERVER_URL;
const devWatch = process.env.DEV_WATCH === '1';
const titles = ['高三爱情故事', '她在黎明前回头', '总裁的隐婚夫人', '重启人生后我成了首富', '这一世换我守护你', '深夜便利店', '逆风翻盘的她', '千金归来', '失忆后前夫急了', '山海之间', '怦然心动', '重回十八岁'];
const tags = [['都市', '逆袭'], ['甜宠', '重逢'], ['悬疑', '情感'], ['校园', '青春']];
const authors = ['黄果官方', '柠檬剧场', '星河工作室', '云端短剧'];

const feed = Array.from({ length: 20 }, (_, i) => ({
  id: 10700 + i,
  title: titles[i % titles.length],
  cover: `/covers/${i + 1}.jpg`,
  description: '一场意外让两个人的命运重新交汇。旧日秘密逐渐浮出水面，他们在选择、误解与重逢之间寻找真正的答案。',
  tags: tags[i % tags.length],
  score: Number((8.7 + (i % 12) / 10).toFixed(1)),
  episode_count: 12 + (i % 18),
  total_episodes: 36 + (i % 20),
  duration: '150',
  hot: 9300000 - i * 318723,
  like_count: 27000 - i * 317,
  collect_count: 11000 - i * 113,
  comment_count: 340 + i * 29,
  is_finished: i % 3 === 0,
  is_original: i % 4 === 0 ? 1 : 0,
  created_at: `2026-11-${String(15 - (i % 12)).padStart(2, '0')} 19:16:47`,
  author: { id: 120 + i, name: authors[i % 4], avatar: '' },
}));
const rank = feed.slice(0, 10).map((v, i) => ({
  rank: i + 1, video_id: v.id, title: v.title, cover: v.cover, tags: v.tags, score: v.score,
  cate_name: ['AI 成人短剧', 'AI 成人漫剧', 'AI 换脸', 'AI 魔改'][i % 4],
  episode_count: v.episode_count, is_finished: v.is_finished, metric_label: '热力指数', metric_value: v.hot,
  metrics: { collect: v.collect_count, comment: v.comment_count, like: v.like_count, play: v.hot * 5 },
}));
const posts = Array.from({ length: 8 }, (_, i) => ({
  id: 60 + i,
  title: ['片场花絮：一场戏拍了二十遍', '本周热议角色投票', '幕后采访：导演聊创作', '你最喜欢哪一段反转'][i % 4],
  desc: '黄果吃瓜社区热门讨论', cover: `/covers/${i + 1}.jpg`, tags: ['吃瓜', '幕后', '热聊'],
  hot: 52000 - i * 3000, publish_time: '2026-11-14 01:07:59',
}));

const videoDetail = (id) => {
  const v = feed.find((item) => item.id === Number(id)) ?? feed[0];
  return {
    ...v,
    episodes: Array.from({ length: Math.min(v.episode_count, 18) }, (_, i) => ({ ep_num: i + 1, title: `第 ${i + 1} 集`, duration: 150, status: 1 })),
    counts: { collect: v.collect_count, comment: v.comment_count, hot: v.hot, like: v.like_count },
    interaction: { collected: false, liked: false, liked_ep: 0 },
  };
};
const wrap = (data) => ({ data, status: 1, msg: '', req_time: Math.floor(Date.now() / 1000) });

function sendJson(res, status, value) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type, authorization',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(value));
}

async function api(req, res) {
  let raw = '';
  for await (const chunk of req) raw += chunk;
  const target = new URL(JSON.parse(raw || '{}').path || '/', base);
  const p = target.pathname;
  if (p === '/api/videos') return sendJson(res, 200, wrap({ items: feed, pagination: { page: 1, pages: 2, size: 20, total: 40 } }));
  if (p.startsWith('/api/videos/category/')) return sendJson(res, 200, wrap({ items: feed, pagination: { page: 1, pages: 1, size: 24, total: 20 } }));
  if (p.startsWith('/api/ranks/')) return sendJson(res, 200, wrap({ type: 'hot', items: rank }));
  if (p === '/api/search') return sendJson(res, 200, wrap({ keyword: target.searchParams.get('q'), items: feed.slice(0, 8), pagination: { page: 1, pages: 1, size: 24, total: 8 } }));
  if (p === '/api/posts') return sendJson(res, 200, wrap({ items: posts, pagination: { page: 1, pages: 1, size: 20, total: 8 } }));
  if (/^\/api\/posts\/\d+$/.test(p)) {
    const post = posts.find((item) => p.endsWith(`/${item.id}`)) ?? posts[0];
    return sendJson(res, 200, wrap({ ...post, content: '<p>片场之外，演员们分享了许多有趣瞬间。这里是一段用于界面验证的图文内容。</p>', author: { id: 9, name: '黄果吃瓜侠', avatar: '' }, counts: { like: 240, comment: 18, collect: 110, hot: 53348 }, interaction: { liked: false, collected: false } }));
  }
  if (/^\/api\/videos\/\d+\/episodes\/\d+\/playback$/.test(p)) return sendJson(res, 200, wrap({ streams: { main: `/media/demo.mp4`, hevc: '' } }));
  if (/^\/api\/videos\/\d+\/comments$/.test(p)) {
    const items = Array.from({ length: 6 }, (_, i) => ({ id: 100 + i, user_id: 200 + i, nickname: ['小鱼', '晚风', '橘子汽水'][i % 3], avatar: '', avatar_color: ['#FF6B3D', '#5B8CFF', '#35B98A'][i % 3], text: ['这一集的反转太意外了。', '演员的情绪很到位，期待下一集。', '已经追到停不下来。'][i % 3], time: `${i + 1}小时前`, like_count: 12 + i, reply_count: i % 2, is_pinned: i === 0, ip_region: '浙江' }));
    return sendJson(res, 200, wrap({ ep: 1, items, pagination: { page: 1, pages: 1, size: 20, total: 6 } }));
  }
  if (/^\/api\/videos\/\d+$/.test(p)) return sendJson(res, 200, wrap(videoDetail(p.split('/').pop())));
  if (p === '/api/account/me') return sendJson(res, 200, wrap({ id: 9, username: 'demo', nickname: '演示账号', avatar: '', avatar_color: '#FF6B3D', counts: { like: 12, collect: 7, history: 5, comment: 3 }, interactions: { like_video_ids: [], favorite_video_ids: [10701], like_video_episodes: [], follow_user_ids: [] } }));
  if (p === '/api/users/me/collects' || p === '/api/users/me/history') return sendJson(res, 200, wrap({ items: feed.slice(0, 6).map((v) => ({ id: v.id, video_id: v.id, title: v.title, cover: v.cover, last_ep: 3, total_ep: v.episode_count, updated_at: v.created_at })), pagination: { page: 1, pages: 1, size: 20, total: 6 } }));
  return sendJson(res, 200, wrap(null));
}

async function proxyApi(req, res) {
  let raw = '';
  for await (const chunk of req) raw += chunk;
  const headers = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    Referer: `${previewSource}/`,
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  };
  if (req.headers.authorization) headers.Authorization = req.headers.authorization;
  const upstream = await fetch(`${previewSource}/api/edge/request`, {
    method: 'POST',
    headers,
    body: raw,
  });
  const body = Buffer.from(await upstream.arrayBuffer());
  res.writeHead(upstream.status, {
    'Content-Type': upstream.headers.get('content-type') || 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

function proxyDevPatchedScript(req, res, pathname, transform) {
  const target = new URL(pathname, devServerUrl);
  fetch(target)
    .then(async (upstream) => {
      let body = await upstream.text();
      body = transform(body);
      res.writeHead(upstream.status, {
        'Content-Type': 'text/javascript; charset=utf-8',
        'Cache-Control': 'no-store',
      });
      res.end(body);
    })
    .catch((error) => {
      res.writeHead(502, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(`开发脚本不可用：${error.message}`);
    });
}

function proxyDev(req, res) {
  if (req.method === 'GET' && req.url === '/ddc_module_loader.js') {
    proxyDevPatchedScript(req, res, '/ddc_module_loader.js', (body) =>
      body
        .replace('this.maxRequestPoolSize = 1000;', 'this.maxRequestPoolSize = 8;'),
    );
    return;
  }
  if (req.method === 'GET' && req.url === '/main_module.bootstrap.js') {
    proxyDevPatchedScript(req, res, '/main_module.bootstrap.js', (body) => {
      const forwardedProto = String(req.headers['x-forwarded-proto'] || 'http');
      const scheme = forwardedProto === 'https' ? 'wss' : 'ws';
      const host = String(req.headers.host || '127.0.0.1:43126');
      return body
        .replaceAll(
          'ws://127.0.0.1:43125/$dwdsSseHandler',
          `${scheme}://${host}/$dwdsSseHandler`,
        )
        .replaceAll(
          'http://127.0.0.1:43125/reload_scripts.json',
          `${forwardedProto}://${host}/reload_scripts.json`,
        );
    });
    return;
  }
  const target = new URL(devServerUrl);
  const upstream = http.request({
    hostname: target.hostname,
    port: target.port || 80,
    path: req.url,
    method: req.method,
    headers: {
      ...req.headers,
      host: `${target.hostname}:${target.port}`,
    },
  }, (upstreamRes) => {
    res.writeHead(upstreamRes.statusCode || 502, upstreamRes.headers);
    upstreamRes.pipe(res);
  });
  upstream.on('error', (error) => {
    res.writeHead(502, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(`开发服务不可用：${error.message}`);
  });
  req.pipe(upstream);
}

const compressionCache = new Map();
const compressibleExtensions = new Set(['.js', '.mjs', '.css', '.json', '.wasm', '.svg', '.ttf', '.otf']);
function compressedStatic(file, encoding) {
  const stat = fs.statSync(file);
  const key = `${file}:${stat.mtimeMs}:${stat.size}:${encoding}`;
  const cached = compressionCache.get(key);
  if (cached) return cached;
  const source = fs.readFileSync(file);
  const output = encoding === 'br'
    ? zlib.brotliCompressSync(source, {
        params: {
          [zlib.constants.BROTLI_PARAM_QUALITY]: 5,
          [zlib.constants.BROTLI_PARAM_SIZE_HINT]: source.length,
        },
      })
    : zlib.gzipSync(source, { level: 6 });
  compressionCache.set(key, output);
  return output;
}

const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.wasm': 'application/wasm', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') return sendJson(res, 204, {});
  if (req.url?.startsWith('/api/edge/request') && req.method === 'POST') return proxyApi(req, res).catch((e) => sendJson(res, 502, { status: 0, msg: `真实源请求失败：${e.message}` }));
  if (devServerUrl) return proxyDev(req, res);
  const p = decodeURIComponent((req.url || '/').split('?')[0]);
  if (p === '/__dev_version') {
    const main = path.join(frontend, 'main.dart.js');
    const stat = fs.existsSync(main) ? fs.statSync(main) : { mtimeMs: 0, size: 0 };
    res.writeHead(200, { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' });
    return res.end(`${stat.mtimeMs}-${stat.size}`);
  }
  if (p.startsWith('/covers/') || p.startsWith('/media/')) {
    const asset = path.join(root, 'web', p);
    if (fs.existsSync(asset)) {
      const contentType = path.extname(asset) === '.jpg'
        ? 'image/jpeg'
        : (path.extname(asset) === '.webm' ? 'video/webm' : 'video/mp4');
      const size = fs.statSync(asset).size;
      const range = req.headers.range;
      if (range) {
        const match = /^bytes=(\d*)-(\d*)$/.exec(range);
        if (match) {
          const start = match[1] ? Number(match[1]) : 0;
          const end = match[2] ? Number(match[2]) : size - 1;
          res.writeHead(206, {
            'Content-Type': contentType,
            'Access-Control-Allow-Origin': '*',
            'Accept-Ranges': 'bytes',
            'Content-Range': `bytes ${start}-${end}/${size}`,
            'Content-Length': end - start + 1,
            'Cache-Control': 'public, max-age=3600',
          });
          return fs.createReadStream(asset, { start, end }).pipe(res);
        }
      }
      res.writeHead(200, {
        'Content-Type': contentType,
        'Access-Control-Allow-Origin': '*',
        'Accept-Ranges': 'bytes',
        'Content-Length': size,
        'Cache-Control': 'public, max-age=3600',
      });
      return fs.createReadStream(asset).pipe(res);
    }
  }
  let file = path.join(frontend, p === '/' ? 'index.html' : p.replace(/^\//, ''));
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(frontend, 'index.html');
  {
    const isHtml = p === '/' || path.extname(file) === '.html';
    const noStore = p === '/main.dart.js' || p === '/flutter_bootstrap.js';
    const cache = isHtml || noStore ? 'no-store' : (p.startsWith('/assets/') || p.startsWith('/canvaskit/') ? 'public, max-age=86400, immutable' : 'public, max-age=3600');
    const ext = path.extname(file);
    const accepted = String(req.headers['accept-encoding'] || '');
    const encoding = accepted.includes('br') ? 'br' : (accepted.includes('gzip') ? 'gzip' : '');
    if (!isHtml && compressibleExtensions.has(ext) && fs.statSync(file).size >= 20 * 1024 && encoding) {
      const output = compressedStatic(file, encoding);
      res.writeHead(200, {
        'Content-Type': mime[ext] || 'application/octet-stream',
        'Cache-Control': cache,
        'Content-Encoding': encoding,
        'Content-Length': output.length,
        Vary: 'Accept-Encoding',
      });
      return res.end(output);
    }
    res.writeHead(200, { 'Content-Type': mime[ext] || 'application/octet-stream', 'Cache-Control': cache });
    if (isHtml && devWatch) {
      const html = fs.readFileSync(file, 'utf8').replace('</body>', `
  <script>
    (function () {
      let current = null;
      setInterval(async function () {
        try {
          const next = await fetch('/__dev_version', { cache: 'no-store' }).then(function (r) { return r.text(); });
          if (current && current !== next) location.reload();
          current = next;
        } catch (_) {}
      }, 2000);
    })();
  </script>
</body>`);
      return res.end(html);
    }
  }
  fs.createReadStream(file).pipe(res);
});

server.on('upgrade', (req, socket, head) => {
  if (!devServerUrl) {
    socket.destroy();
    return;
  }
  const target = new URL(devServerUrl);
  const upstream = net.connect(
    Number(target.port || 80),
    target.hostname,
    () => {
      const headers = Object.entries(req.headers)
        .map(([name, value]) => `${name}: ${Array.isArray(value) ? value.join(', ') : value}`)
        .join('\r\n');
      upstream.write(`${req.method} ${req.url} HTTP/${req.httpVersion}\r\n${headers}\r\n\r\n`);
      if (head.length) upstream.write(head);
      upstream.pipe(socket);
      socket.pipe(upstream);
    },
  );
  upstream.on('error', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
});

server.listen(port, '0.0.0.0', () => console.log(`mock server ${base}`));
