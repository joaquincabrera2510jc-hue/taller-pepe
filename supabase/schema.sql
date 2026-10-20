-- =====================================================================
--  Taller Pepe — base de datos en Supabase (sincronización entre PCs)
--  Pegar completo en Supabase > SQL Editor > New query > Run.
--  Se puede volver a ejecutar sin perder datos.
-- =====================================================================

-- ---------- Usuarios habilitados ----------------------------------------
-- La cuenta se crea en Authentication > Users > Add user (usuario@tallerpepe.local)
-- y después se habilita con:  select public.tph_alta_usuario('pepe', 'Pepe');
create table if not exists public.tph_usuarios (
  id             uuid primary key references auth.users(id) on delete cascade,
  usuario        text not null unique check (usuario ~ '^[a-z0-9._-]{3,30}$'),
  nombre         text not null check (length(trim(nombre)) > 0),
  activo         boolean not null default true,
  creado         timestamptz not null default now(),
  ultimo_ingreso timestamptz
);

-- ---------- Datos del taller ---------------------------------------------
-- Una fila por cliente, vehículo o servicio (y una para la configuración).
-- Los borrados quedan marcados para que no reaparezcan en otra PC.
create table if not exists public.tph_registros (
  tabla       text not null check (tabla in ('clientes','vehiculos','servicios','config')),
  id          text not null check (length(id) between 1 and 80),
  datos       jsonb,
  borrado     boolean not null default false,
  origen      text not null default '',
  por         uuid references auth.users(id) on delete set null,
  actualizado timestamptz not null default now(),
  primary key (tabla, id)
);
create index if not exists tph_registros_actualizado on public.tph_registros (actualizado);

-- Próximo número de presupuesto (lo da el servidor: dos PCs nunca repiten número)
create table if not exists public.tph_contador (
  id    integer primary key default 1 check (id = 1),
  valor integer not null default 1 check (valor >= 1)
);

-- ---------- Ayudantes ------------------------------------------------------
create or replace function public.tph_permitido() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.tph_usuarios where id = auth.uid() and activo)
$$;

create or replace function public.tph_registros_sello() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.actualizado := clock_timestamp();
  new.por := auth.uid();
  return new;
end $$;
drop trigger if exists tph_registros_sello on public.tph_registros;
create trigger tph_registros_sello before insert or update on public.tph_registros
  for each row execute function public.tph_registros_sello();

-- Al ingresar: registra la hora y devuelve el usuario (null si no está habilitado)
create or replace function public.tph_ingreso() returns public.tph_usuarios
language plpgsql security definer set search_path = public as $$
declare r public.tph_usuarios;
begin
  update public.tph_usuarios set ultimo_ingreso = now()
   where id = auth.uid() and activo
   returning * into r;
  return r;
end $$;

-- Pide el próximo número de presupuesto y lo reserva
create or replace function public.tph_siguiente_numero() returns integer
language plpgsql security definer set search_path = public as $$
declare v integer;
begin
  if not public.tph_permitido() then raise exception 'No tenés permiso.'; end if;
  insert into public.tph_contador (id, valor) values (1, 2)
  on conflict (id) do update set valor = public.tph_contador.valor + 1
  returning valor - 1 into v;
  return v;
end $$;

-- Se asegura de que el contador no quede por debajo de p_valor (nunca lo baja)
create or replace function public.tph_numero_minimo(p_valor integer) returns integer
language plpgsql security definer set search_path = public as $$
declare v integer;
begin
  if not public.tph_permitido() then raise exception 'No tenés permiso.'; end if;
  insert into public.tph_contador (id, valor) values (1, greatest(coalesce(p_valor, 1), 1))
  on conflict (id) do update set valor = greatest(public.tph_contador.valor, excluded.valor)
  returning valor into v;
  return v;
end $$;

-- Cambiar el próximo número a mano (desde Configuración)
create or replace function public.tph_fijar_numero(p_valor integer) returns integer
language plpgsql security definer set search_path = public as $$
declare v integer;
begin
  if not public.tph_permitido() then raise exception 'No tenés permiso.'; end if;
  insert into public.tph_contador (id, valor) values (1, greatest(coalesce(p_valor, 1), 1))
  on conflict (id) do update set valor = excluded.valor
  returning valor into v;
  return v;
end $$;

-- Habilitar un usuario ya creado en Authentication (solo desde el SQL Editor)
create or replace function public.tph_alta_usuario(p_usuario text, p_nombre text) returns text
language plpgsql security definer set search_path = public, auth as $$
declare v_id uuid; v_usr text := lower(trim(p_usuario));
begin
  select id into v_id from auth.users where lower(email) = v_usr || '@tallerpepe.local';
  if v_id is null then
    raise exception 'Primero creá el usuario %@tallerpepe.local en Authentication > Users > Add user.', v_usr;
  end if;
  insert into public.tph_usuarios (id, usuario, nombre) values (v_id, v_usr, trim(p_nombre))
  on conflict (id) do update set usuario = excluded.usuario, nombre = excluded.nombre, activo = true;
  return 'Usuario ' || v_usr || ' habilitado';
end $$;

-- ---------- Permisos ---------------------------------------------------------
alter table public.tph_usuarios  enable row level security;
alter table public.tph_registros enable row level security;
alter table public.tph_contador  enable row level security;

revoke all on public.tph_usuarios, public.tph_registros, public.tph_contador from anon, authenticated;
grant select on public.tph_usuarios, public.tph_registros, public.tph_contador to authenticated;
grant insert (tabla, id, datos, borrado, origen), update (tabla, id, datos, borrado, origen) on public.tph_registros to authenticated;

revoke all on function public.tph_permitido(), public.tph_ingreso(), public.tph_siguiente_numero(),
                       public.tph_numero_minimo(integer), public.tph_fijar_numero(integer),
                       public.tph_alta_usuario(text, text) from public, anon, authenticated;
grant execute on function public.tph_permitido(), public.tph_ingreso(), public.tph_siguiente_numero(),
                          public.tph_numero_minimo(integer), public.tph_fijar_numero(integer) to authenticated;

drop policy if exists leer on public.tph_usuarios;
create policy leer on public.tph_usuarios for select to authenticated using (public.tph_permitido());

drop policy if exists leer on public.tph_registros;
create policy leer on public.tph_registros for select to authenticated using (public.tph_permitido());
drop policy if exists crear on public.tph_registros;
create policy crear on public.tph_registros for insert to authenticated with check (public.tph_permitido());
drop policy if exists editar on public.tph_registros;
create policy editar on public.tph_registros for update to authenticated
  using (public.tph_permitido()) with check (public.tph_permitido());

drop policy if exists leer on public.tph_contador;
create policy leer on public.tph_contador for select to authenticated using (public.tph_permitido());

-- ---------- Tiempo real (la app se actualiza sola cuando otra PC carga algo) ----
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['tph_registros','tph_contador'] loop
      if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

-- =====================================================================
--  Portal web de clientes (solo lectura)
--  Un usuario del portal puede ver una o varias empresas/clientes.
--  Los usuarios se crean desde la app del taller (ficha del cliente → Acceso web).
-- =====================================================================
create table if not exists public.tph_portal_usuarios (
  id             uuid primary key references auth.users(id) on delete cascade,
  usuario        text not null unique check (usuario ~ '^[a-z0-9._-]{3,30}$'),
  nombre         text not null check (length(trim(nombre)) > 0),
  activo         boolean not null default true,
  creado         timestamptz not null default now(),
  ultimo_ingreso timestamptz
);
create table if not exists public.tph_portal_accesos (
  usuario_id uuid not null references public.tph_portal_usuarios(id) on delete cascade,
  cliente_id text not null,
  creado     timestamptz not null default now(),
  primary key (usuario_id, cliente_id)
);

-- Clientes que puede ver el usuario del portal conectado
create or replace function public.tph_portal_clientes() returns setof text
language sql stable security definer set search_path = public as $$
  select a.cliente_id from public.tph_portal_accesos a
    join public.tph_portal_usuarios u on u.id = a.usuario_id
   where u.id = auth.uid() and u.activo
$$;

-- Al ingresar al portal: datos del usuario y sus clientes (null si no tiene acceso)
create or replace function public.tph_portal_ingreso() returns json
language plpgsql security definer set search_path = public as $$
declare r public.tph_portal_usuarios;
begin
  update public.tph_portal_usuarios set ultimo_ingreso = now()
   where id = auth.uid() and activo returning * into r;
  if r.id is null then return null; end if;
  return json_build_object('usuario', r.usuario, 'nombre', r.nombre,
    'clientes', coalesce((select json_agg(cliente_id) from public.tph_portal_accesos where usuario_id = r.id), '[]'::json));
end $$;

-- ---- gestión desde la app del taller (solo usuarios del taller) ----
create or replace function public.tph_portal_lista()
returns table (usuario text, nombre text, activo boolean, ultimo_ingreso timestamptz, clientes text[])
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.tph_permitido() then raise exception 'No tenés permiso.'; end if;
  return query
    select u.usuario, u.nombre, u.activo, u.ultimo_ingreso,
           coalesce(array_agg(a.cliente_id order by a.cliente_id) filter (where a.cliente_id is not null), '{}')
      from public.tph_portal_usuarios u left join public.tph_portal_accesos a on a.usuario_id = u.id
     group by u.id order by u.usuario;
end $$;

create or replace function public.tph_portal_crear(p_usuario text, p_nombre text, p_password text, p_cliente text)
returns text
language plpgsql security definer set search_path = public, auth, extensions as $$
declare v_usr text := lower(trim(p_usuario)); v_email text; v_id uuid := gen_random_uuid();
begin
  if not public.tph_permitido() then raise exception 'No tenés permiso.'; end if;
  if v_usr !~ '^[a-z0-9._-]{3,30}$' then raise exception 'El usuario lleva de 3 a 30 letras minúsculas, números, punto o guion.'; end if;
  if coalesce(trim(p_nombre), '') = '' then raise exception 'Escribí el nombre.'; end if;
  if length(coalesce(p_password, '')) < 6 then raise exception 'La contraseña tiene que tener al menos 6 caracteres.'; end if;
  v_email := v_usr || '@tallerpepe.local';
  if exists (select 1 from auth.users where lower(email) = v_email) then raise exception 'Ese usuario ya existe. Elegí otro nombre.'; end if;
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, recovery_token, email_change, email_change_token_new,
                          email_change_token_current, phone_change, phone_change_token, reauthentication_token)
  values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
          crypt(p_password, gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}', jsonb_build_object('usuario', v_usr, 'nombre', trim(p_nombre), 'portal', true),
          now(), now(), '', '', '', '', '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_id, v_id::text, 'email',
          jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true), now(), now(), now());
  insert into public.tph_portal_usuarios (id, usuario, nombre) values (v_id, v_usr, trim(p_nombre));
  if coalesce(p_cliente, '') <> '' then
    insert into public.tph_portal_accesos (usuario_id, cliente_id) values (v_id, p_cliente);
  end if;
  return v_usr;
end $$;

create or replace function public.tph_portal_vincular(p_usuario text, p_cliente text, p_dar boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.tph_permitido() then raise exception 'No tenés permiso.'; end if;
  select id into v_id from public.tph_portal_usuarios where usuario = lower(trim(p_usuario));
  if v_id is null then raise exception 'Ese usuario web no existe.'; end if;
  if p_dar then
    insert into public.tph_portal_accesos (usuario_id, cliente_id) values (v_id, p_cliente) on conflict do nothing;
  else
    delete from public.tph_portal_accesos where usuario_id = v_id and cliente_id = p_cliente;
  end if;
end $$;

create or replace function public.tph_portal_editar(p_usuario text, p_nombre text, p_password text, p_activo boolean)
returns void
language plpgsql security definer set search_path = public, auth, extensions as $$
declare v_id uuid;
begin
  if not public.tph_permitido() then raise exception 'No tenés permiso.'; end if;
  select id into v_id from public.tph_portal_usuarios where usuario = lower(trim(p_usuario));
  if v_id is null then raise exception 'Ese usuario web no existe.'; end if;
  if coalesce(p_password, '') <> '' then
    if length(p_password) < 6 then raise exception 'La contraseña tiene que tener al menos 6 caracteres.'; end if;
    update auth.users set encrypted_password = crypt(p_password, gen_salt('bf')), updated_at = now() where id = v_id;
  end if;
  update public.tph_portal_usuarios
     set nombre = coalesce(nullif(trim(p_nombre), ''), nombre), activo = coalesce(p_activo, activo)
   where id = v_id;
end $$;

alter table public.tph_portal_usuarios enable row level security;
alter table public.tph_portal_accesos  enable row level security;
revoke all on public.tph_portal_usuarios, public.tph_portal_accesos from anon, authenticated;

revoke all on function public.tph_portal_clientes(), public.tph_portal_ingreso(), public.tph_portal_lista(),
                       public.tph_portal_crear(text, text, text, text), public.tph_portal_vincular(text, text, boolean),
                       public.tph_portal_editar(text, text, text, boolean) from public, anon;
grant execute on function public.tph_portal_clientes(), public.tph_portal_ingreso(), public.tph_portal_lista(),
                          public.tph_portal_crear(text, text, text, text), public.tph_portal_vincular(text, text, boolean),
                          public.tph_portal_editar(text, text, text, boolean) to authenticated;

-- El cliente solo ve lo suyo, y nunca lo borrado
drop policy if exists portal_leer on public.tph_registros;
create policy portal_leer on public.tph_registros for select to authenticated using (
  not borrado and (
    (tabla = 'clientes' and id in (select public.tph_portal_clientes()))
    or (tabla in ('vehiculos', 'servicios') and datos->>'clienteId' in (select public.tph_portal_clientes()))
    or (tabla = 'config' and exists (select public.tph_portal_clientes()))
  )
);
