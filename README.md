# Taller Pepe — app de escritorio con sincronización

App de escritorio para Windows: clientes, vehículos, servicios, presupuestos y estadísticas.
Los datos se guardan en la nube (Supabase) y se ven iguales en todas las PCs. La app se actualiza sola.
Funciona igual que la de López Motors.

## Cómo está armada

- **Supabase** (proyecto propio de Taller Pepe) guarda los clientes, vehículos, servicios, la configuración y el número de presupuesto.
  Lo que se carga en una PC aparece en las demás al instante.
- **GitHub** (este repositorio) arma el instalador y guarda las versiones. Las apps instaladas buscan acá las actualizaciones.
- **En cada PC** se siguen guardando los PDF en `Documentos\Taller Pepe` (una carpeta por cliente y por matrícula), más `_datos_taller.json` y `_respaldos` como copia local.

## Puesta en marcha (una sola vez)

### 1. Supabase
1. En supabase.com, **New project** → nombre `taller-pepe`, región **South America (São Paulo)**.
2. **SQL Editor → New query**: pegá todo `supabase/schema.sql` y tocá **Run**.
3. **Authentication → Users → Add user → Create new user**:
   - Email: `pepe@tallerpepe.local` (el usuario va antes de la @)
   - Contraseña: mínimo 6 caracteres
   - Marcá **Auto Confirm User**
4. Volvé al **SQL Editor** y ejecutá:
   ```sql
   select public.tph_alta_usuario('pepe', 'Pepe');
   ```
   Para más usuarios (por ejemplo un mecánico), repetí los pasos 3 y 4 con otro nombre.
5. **Project Settings → API**: copiá **Project URL** y la clave **anon public** en `src/config.js`.

### 2. GitHub
1. Creá un repositorio nuevo llamado **`taller-pepe`** (en la misma cuenta que `control-articulos`).
2. Subí todos estos archivos (incluida la carpeta oculta `.github`).
3. En la pestaña **Actions** se arma el instalador. Cuando termina, queda en **Releases**: `Taller-Pepe-Setup-X.X.X.exe`.

### 3. Instalar en cada PC
1. Descargá y ejecutá `Taller-Pepe-Setup-X.X.X.exe`. Si Windows muestra "Windows protegió su PC": **Más información → Ejecutar de todos modos**.
2. **Primero en la PC donde ya está cargado todo**: al ingresar, los datos de esa PC se suben a la nube.
3. Después en las demás PCs: al ingresar, bajan todo de la nube.

El instalador viejo (`INSTALAR Taller Pepe.bat`) ya no hace falta. La carpeta `%LOCALAPPDATA%\TallerPepe` de la versión vieja se puede borrar.

## Portal web de clientes (solo lectura)

Página: **https://joaquincabrera2510jc-hue.github.io/taller-pepe/** (carpeta `portal/`, se publica sola con GitHub Pages).

- El cliente entra desde el celular o la PC con su usuario y ve sus vehículos, km, próximo service, historial de servicios y el detalle de cada presupuesto. No puede cambiar nada.
- Los usuarios se crean en la app del taller: **Clientes → (cliente) → Acceso web del cliente → + Crear usuario web**.
- Un mismo usuario puede ver **varias empresas**: entrá a la otra empresa y tocá **+ Dar acceso a un usuario existente**.
- Desde ahí también se cambia la contraseña o se quita el acceso.
- Los usuarios del portal no pueden entrar a la app del taller, y los del taller no entran al portal.

## Publicar una versión nueva
1. Cambiá los archivos que correspondan.
2. Subí el número de `"version"` en `package.json` (por ejemplo de `1.1.0` a `1.1.1`).
3. GitHub arma y publica el instalador solo. Cada app lo baja al abrirse (y cada 30 minutos) y muestra **Reiniciar y actualizar**.

## Sin internet
- Sin conexión no se puede ingresar.
- Si se corta internet con la app abierta, la pantalla se bloquea hasta que vuelva la conexión.

## Bueno saber
- **Número de presupuesto:** lo da el servidor, así dos PCs nunca repiten número. Se puede cambiar en Configuración.
- **Borrados:** si se borra un cliente en una PC, desaparece en todas (con sus vehículos y servicios). Los PDF ya guardados en cada PC no se borran.
- **Si dos PCs editan lo mismo a la vez**, queda lo último que se guardó.
- **Plan gratuito de Supabase:** el proyecto se pausa después de 7 días seguidos sin uso. Se reactiva desde el panel de Supabase y no se pierden los datos.
- **Respaldo:** en Configuración, **Descargar respaldo (.json)**.
- Los presupuestos son comprobantes internos, no son CFE de DGI.
