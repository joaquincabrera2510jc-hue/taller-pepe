const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('tallerNative', {
  root: () => ipcRenderer.invoke('tp:root'),
  pick: () => ipcRenderer.invoke('tp:pick'),
  mkdir: (parts) => ipcRenderer.invoke('tp:mkdir', parts),
  stat: (parts) => ipcRenderer.invoke('tp:stat', parts),
  read: (parts) => ipcRenderer.invoke('tp:read', parts),
  write: (parts, data) => ipcRenderer.invoke('tp:write', parts, data),
  fullPath: (parts) => ipcRenderer.invoke('tp:full', parts),
  open: (parts) => ipcRenderer.invoke('tp:open', parts),
  show: (parts) => ipcRenderer.invoke('tp:show', parts),
  version: () => ipcRenderer.invoke('tp:version'),
  onUpdate: (cb) => ipcRenderer.on('actualizacion', (_e, datos) => cb(datos)),
  instalarActualizacion: () => ipcRenderer.send('tp:instalar-actualizacion')
});
