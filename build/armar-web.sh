#!/usr/bin/env bash
# Arma la carpeta _site que se publica en GitHub Pages:
#   /            → portal de clientes (portal/)
#   /taller/     → la app completa del taller en el navegador (src/)
#   /servicio/   → la misma app, que abre directo en "Nuevo servicio" (para el celular)
set -euo pipefail
rm -rf _site && mkdir -p _site
cp -r portal/. _site/
app () { # $1 carpeta, $2 modo, $3 nombre corto
  local d="_site/$1"; mkdir -p "$d"
  cp src/index.html src/app.js src/pdf-lib.min.js src/icon.png "$d/"
  sed -i 's#../node_modules/@supabase/supabase-js/dist/umd/supabase.js#../supabase.js#' "$d/index.html"
  grep -q '"../supabase.js"' "$d/index.html"
  sed -i "s#<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">#<meta name=\"viewport\" content=\"width=device-width,initial-scale=1,viewport-fit=cover\">\n<link rel=\"manifest\" href=\"manifest.webmanifest\">\n<link rel=\"apple-touch-icon\" href=\"icon.png\">\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">\n<meta name=\"mobile-web-app-capable\" content=\"yes\">\n<meta name=\"apple-mobile-web-app-status-bar-style\" content=\"black\">\n<meta name=\"apple-mobile-web-app-title\" content=\"$3\">\n<meta name=\"theme-color\" content=\"\#141414\">\n<meta name=\"robots\" content=\"noindex\">#" "$d/index.html"
  grep -q 'manifest.webmanifest' "$d/index.html"
  sed "s#^  DOMINIO_USUARIOS:#  MODO: \"$2\",\n  DOMINIO_USUARIOS:#" src/config.js > "$d/config.js"
  printf '{"name":"Taller Pepe – %s","short_name":"%s","start_url":"./","scope":"./","display":"standalone","background_color":"#141414","theme_color":"#141414","icons":[{"src":"icon.png","sizes":"256x256","type":"image/png"}]}\n' "$3" "$3" > "$d/manifest.webmanifest"
}
app taller completo "TPH Taller"
app servicio servicio "TPH Servicio"
grep -q 'MODO: "servicio"' _site/servicio/config.js
