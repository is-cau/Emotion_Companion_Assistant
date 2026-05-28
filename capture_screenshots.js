const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const BUILD_DIR = path.join(__dirname, 'build', 'web');
const OUTPUT_DIR = path.join(__dirname, 'assets', 'screenshots', 'desktop');
const BASE_URL = `http://localhost:${PORT}`;

async function startServer() {
  return new Promise((resolve) => {
    const mimeTypes = {
      '.html': 'text/html', '.js': 'application/javascript',
      '.wasm': 'application/wasm', '.json': 'application/json',
      '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
      '.css': 'text/css', '.ttf': 'font/ttf', '.otf': 'font/otf',
      '.ico': 'image/x-icon',
    };
    const server = http.createServer((req, res) => {
      let fp = path.join(BUILD_DIR, req.url === '/' ? 'index.html' : req.url.split(/[?#]/)[0]);
      if (!fs.existsSync(fp)) fp = path.join(BUILD_DIR, 'index.html');
      const ext = path.extname(fp);
      res.writeHead(200, { 'Content-Type': mimeTypes[ext] || 'application/octet-stream' });
      res.end(fs.readFileSync(fp));
    });
    server.listen(PORT, () => { console.log(`Server: ${BASE_URL}`); resolve(server); });
  });
}

async function main() {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const server = await startServer();

  // Set up a downloads directory
  const downloadDir = path.join(__dirname, 'build', 'downloads');
  if (!fs.existsSync(downloadDir)) fs.mkdirSync(downloadDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
    acceptDownloads: true,
  });
  const page = await context.newPage();

  // Track downloaded files
  const downloads = [];

  page.on('download', async (download) => {
    const filename = download.suggestedFilename();
    console.log(`Download started: ${filename}`);
    const filePath = path.join(downloadDir, filename);
    await download.saveAs(filePath);
    downloads.push(filePath);
    console.log(`Download saved: ${filename}`);
  });

  try {
    console.log('Loading screenshot app...');
    await page.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 60000 });

    // Wait for the completion marker or timeout after 2 minutes
    console.log('Waiting for screenshots to be captured (max 120s)...');
    try {
      await page.waitForSelector('#screenshots-done', { timeout: 120000 });
      console.log('Screenshot capture completed!');
    } catch (e) {
      console.log('Timeout waiting for completion marker, checking downloads...');
    }

    // Wait a bit more for any pending downloads
    await new Promise(r => setTimeout(r, 5000));

    console.log(`\nTotal downloads: ${downloads.length}`);

    // Move downloads to the output directory with correct names
    for (const dl of downloads) {
      const filename = path.basename(dl);
      const destPath = path.join(OUTPUT_DIR, filename);
      fs.copyFileSync(dl, destPath);
      console.log(`Copied: ${filename} -> ${destPath}`);
    }

    // Also check for any PNG files in download dir that might not be tracked
    const dlFiles = fs.readdirSync(downloadDir).filter(f => f.endsWith('.png'));
    for (const f of dlFiles) {
      const src = path.join(downloadDir, f);
      const dest = path.join(OUTPUT_DIR, f);
      if (!fs.existsSync(dest)) {
        fs.copyFileSync(src, dest);
        console.log(`Copied missed file: ${f}`);
      }
    }

    await page.screenshot({ path: path.join(OUTPUT_DIR, '_final_state.png') });

  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await browser.close();
    server.close();
  }
}

main();
