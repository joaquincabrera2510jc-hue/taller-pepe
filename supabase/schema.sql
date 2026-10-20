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
