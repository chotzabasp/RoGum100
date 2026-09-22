// เว็บ Gum100 เป็นไฟล์เดียว (index.html) ไม่มี build step — server นี้แค่เสิร์ฟไฟล์ตรงๆ จากโฟลเดอร์โปรเจกต์
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const port = process.env.PORT || 8080;
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

http.createServer((req, res) => {
  let reqPath = decodeURIComponent(req.url.split('?')[0]);
  if (reqPath === '/') reqPath = '/index.html';
  const filePath = path.join(root, reqPath);
  // กันไม่ให้หลุดออกนอกโฟลเดอร์โปรเจกต์
  if (!filePath.startsWith(root)) { res.writeHead(403); res.end('forbidden'); return; }
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('not found'); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(filePath)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(port, () => console.log('Gum100 static server on http://localhost:' + port));
