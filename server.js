const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5050;
const PORTAL_PATH = path.join(__dirname, 'portal', 'index.html');
const LOGO_PATH = path.join(__dirname, 'portal', 'company-logo.svg');

const server = http.createServer((req, res) => {
  if (req.url === '/company-logo.svg') {
    fs.readFile(LOGO_PATH, (err, data) => {
      if (err) {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Company logo not found.');
      } else {
        res.writeHead(200, { 'Content-Type': 'image/svg+xml; charset=utf-8' });
        res.end(data);
      }
    });
    return;
  }
  if (req.url === '/' || req.url === '/index.html') {
    fs.readFile(PORTAL_PATH, (err, data) => {
      if (err) {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Error loading portal: ' + err.message);
      } else {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(data);
      }
    });
  } else {
    res.writeHead(302, { 'Location': '/' });
    res.end();
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Headset Inventory Portal is running at http://localhost:${PORT}`);
});
