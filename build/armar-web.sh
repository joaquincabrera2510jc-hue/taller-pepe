#!/usr/bin/env bash
# Arma la carpeta _site que se publica en GitHub Pages:
#   /            → portal de clientes (portal/)
#   /servicio/   → carga rápida de servicios desde el celular (portal/servicio/)
#   /taller/     → la app completa del taller en el navegador (src/)
set -euo pipefail
rm -rf _site && mkdir -p _site/taller
cp -r portal/. _site/
cp src/index.html src/app.js src/pdf-lib.min.js src/config.js src/icon.png _site/taller/
sed -i 's#../node_modules/@supabase/supabase-js/dist/umd/supabase.js#../supabase.js#' _site/taller/index.html
grep -q '"../supabase.js"' _site/taller/index.html
