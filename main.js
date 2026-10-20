const { app, BrowserWindow, ipcMain, dialog, shell, Menu } = require('electron');
const path = require('path');
const fs = require('fs');

let autoUpdater = null;
try { ({ autoUpdater } = require('electron-updater')); } catch (e) { /* en desarrollo puede no estar */ }

// El "user agent" se deja solo con caracteres simples (Supabase no acepta tildes ahí)
app.userAgentFallback = app.userAgentFallback.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^\x20-\x7E]/g, '');

const APP_ID = 'uy.tallerpepe.gestion';
app.setAppUserModelId(APP_ID);
if (!app.requestSingleInstanceLock()) { app.quit(); }

let win = null;
let cfg = {};
const cfgFile = () => path.join(app.getPath('userData'), 'config.json');
function loadCfg() { try { cfg = JSON.parse(fs.readFileSync(cfgFile(), 'utf8')) || {}; } catch (e) { cfg = {}; } }
function saveCfg() { try { fs.mkdirSync(path.dirname(cfgFile()), { recursive: true }); fs.writeFileSync(cfgFile(), JSON.stringify(cfg, null, 1)); } catch (e) {} }

// Carpeta de clientes (por defecto: Documentos\Taller Pepe)
function root() {
  if (!cfg.root) { cfg.root = path.join(app.getPath('documents'), 'Taller Pepe'); saveCfg(); }
  fs.mkdirSync(cfg.root, { recursive: true });
  return cfg.root;
}
// Toda ruta se resuelve dentro de la carpeta de clientes
function resolve(parts) {
  const r = path.resolve(root());
  const p = path.resolve(r, ...(Array.isArray(parts) ? parts : []).map(String));
  if (p !== r && !p.startsWith(r + path.sep)) throw new Error('Ruta fuera de la carpeta de clientes');
  return p;
}

ipcMain.handle('tp:root', () => ({ name: path.basename(root()), full: root() }));
ipcMain.handle('tp:pick', async (e) => {
  const r = await dialog.showOpenDialog(BrowserWindow.fromWebContents(e.sender), {
    title: 'Elegir la carpeta de clientes', defaultPath: root(), buttonLabel: 'Usar esta carpeta',
    properties: ['openDirectory', 'createDirectory']
  });
  if (r.canceled || !r.filePaths[0]) return null;
  cfg.root = r.filePaths[0]; saveCfg();
  return { name: path.basename(cfg.root), full: cfg.root };
});
ipcMain.handle('tp:mkdir', (e, parts) => { fs.mkdirSync(resolve(parts), { recursive: true }); return true; });
ipcMain.handle('tp:stat', (e, parts) => { try { const s = fs.statSync(resolve(parts)); return s.isDirectory() ? 'dir' : 'file'; } catch (_) { return null; } });
ipcMain.handle('tp:read', (e, parts) => { try { return fs.readFileSync(resolve(parts), 'utf8'); } catch (_) { return null; } });
ipcMain.handle('tp:write', (e, parts, data) => {
  const p = resolve(parts);
  const tmp = p + '.tmp';
  try {
    fs.mkdirSync(path.dirname(p), { recursive: true });
    fs.writeFileSync(tmp, typeof data === 'string' ? data : Buffer.from(data));
    fs.renameSync(tmp, p);
    return true;
  } catch (err) {
    try { fs.unlinkSync(tmp); } catch (_) {}
    return (err && (err.code === 'EBUSY' || err.code === 'EPERM')) ? 'El archivo está abierto en otro programa' : String(err && err.message || err);
  }
});
ipcMain.handle('tp:full', (e, parts) => resolve(parts));
ipcMain.handle('tp:open', (e, parts) => shell.openPath(resolve(parts)));
ipcMain.handle('tp:show', (e, parts) => { shell.showItemInFolder(resolve(parts)); return true; });

function enviar(canal, datos) { if (win && !win.isDestroyed()) win.webContents.send(canal, datos); }

// ---------- actualizaciones automáticas (GitHub Releases) ----------
function configurarActualizaciones() {
  if (!autoUpdater || !app.isPackaged) return;
  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;
  autoUpdater.on('update-available', (i) => enviar('actualizacion', { estado: 'descargando', version: i.version, porcentaje: 0 }));
  autoUpdater.on('download-progress', (p) => enviar('actualizacion', { estado: 'descargando', porcentaje: p.percent }));
  autoUpdater.on('update-downloaded', (i) => enviar('actualizacion', { estado: 'lista', version: i.version }));
  autoUpdater.on('error', (err) => enviar('actualizacion', { estado: 'error', mensaje: String(err && err.message || err) }));
  const buscar = () => autoUpdater.checkForUpdates().catch(() => {});
  buscar();
  setInterval(buscar, 30 * 60 * 1000); // cada 30 minutos
}
ipcMain.handle('tp:version', () => app.getVersion());
ipcMain.on('tp:instalar-actualizacion', () => { if (autoUpdater) autoUpdater.quitAndInstall(false, true); });

function createWindow() {
  win = new BrowserWindow({
    width: 1320, height: 860, minWidth: 900, minHeight: 600, show: false,
    title: 'Taller Pepe', icon: path.join(__dirname, process.platform === 'win32' ? path.join('build', 'icon.ico') : path.join('src', 'icon.png')),
    backgroundColor: '#141414', autoHideMenuBar: true,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false, sandbox: true, spellcheck: false }
  });
  Menu.setApplicationMenu(null);
  win.loadFile(path.join(__dirname, 'src', 'index.html'));
  win.once('ready-to-show', () => { win.maximize(); win.show(); });
  win.webContents.setWindowOpenHandler(({ url }) => { if (/^https?:/i.test(url)) shell.openExternal(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (ev, url) => { if (!url.startsWith('file:')) ev.preventDefault(); });
  // Zoom con Ctrl + / Ctrl - / Ctrl 0 y recarga con F5
  win.webContents.on('before-input-event', (ev, input) => {
    if (input.type !== 'keyDown') return;
    const wc = win.webContents;
    if (input.control && (input.key === '+' || input.key === '=')) { wc.setZoomLevel(wc.getZoomLevel() + 0.5); ev.preventDefault(); }
    else if (input.control && input.key === '-') { wc.setZoomLevel(wc.getZoomLevel() - 0.5); ev.preventDefault(); }
    else if (input.control && input.key === '0') { wc.setZoomLevel(0); ev.preventDefault(); }
    else if (input.key === 'F5') { wc.reload(); ev.preventDefault(); }
  });
}

app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });
app.whenReady().then(() => { loadCfg(); root(); createWindow(); configurarActualizaciones(); });
app.on('window-all-closed', () => app.quit());
