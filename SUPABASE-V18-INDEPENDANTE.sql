-- T·Factory V18 INDÉPENDANTE — dans le MÊME projet Supabase que V17.
-- Ne modifie PAS public.tfactory_state ni les résultats de V17.
-- À exécuter une seule fois dans SQL Editor avant de déployer la V18.
-- Le compte administrateur existant (tfactory_admins) est réutilisé.

create table if not exists public.tfactory_v18_state (
 id integer primary key default 1 check (id=1),
 data jsonb not null default '{"teams":[]}'::jsonb,
 updated_at timestamptz not null default now()
);
alter table public.tfactory_v18_state enable row level security;
grant select,update on public.tfactory_v18_state to authenticated;
grant select on public.tfactory_admins to authenticated;
create policy "V18 admin read" on public.tfactory_v18_state for select to authenticated
 using (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())));
create policy "V18 admin write" on public.tfactory_v18_state for update to authenticated
 using (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())))
 with check (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())));
-- Copie initiale de V17 uniquement si V18 n'a pas déjà de données.
insert into public.tfactory_v18_state(id,data)
select 1,data from public.tfactory_state where id=1
on conflict (id) do nothing;

-- T·Factory V16 — à exécuter une seule fois dans SQL Editor.
-- Ne remplace pas les données importées dans tfactory_v18_state.

-- Autoriser la lecture et la modification aux comptes authentifiés,
-- les règles RLS existantes limitent les accès aux administrateurs.
grant select, update on table public.tfactory_v18_state to authenticated;
grant select on table public.tfactory_admins to authenticated;

-- Horodatage automatique pour éviter d'écraser une saisie concurrente.
create or replace function public.tfactory_v18_touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
drop trigger if exists tfactory_v18_state_timestamp on public.tfactory_v18_state;
create trigger tfactory_v18_state_timestamp
before update on public.tfactory_v18_state
for each row execute function public.tfactory_v18_touch_updated_at();

-- Accès public limité au Live : retire commentaires, jurés, configurations
-- et évaluations non publiées. La table complète reste privée.
create or replace function public.tfactory_v18_live_state()
returns jsonb language plpgsql stable security definer
set search_path = '' as $$
declare
  source jsonb;
  teams jsonb := '[]'::jsonb;
  team jsonb;
  pitch jsonb;
  published boolean;
  p integer;
  i integer;
  team_count integer;
  active_count integer;
  published_count integer;
  pitches jsonb;
begin
  select data into source from public.tfactory_v18_state where id=1;
  if source is null then return jsonb_build_object('teams','[]'::jsonb); end if;
  team_count := jsonb_array_length(coalesce(source->'teams','[]'::jsonb));
  for i in 0..team_count-1 loop
    team := source->'teams'->i;
    pitches := '[]'::jsonb;
    for p in 0..7 loop
      select count(*),count(*) filter (where coalesce((x->'pitches'->p->>'locked')::boolean,false))
      into active_count,published_count
      from jsonb_array_elements(source->'teams') x
      where coalesce((x->>'joinedAt')::integer,0)<=p;
      published := active_count>0 and active_count=published_count;
      pitch := team->'pitches'->p;
      if published and coalesce((team->>'joinedAt')::integer,0)<=p
         and pitch is not null and pitch<>'null'::jsonb then
        pitches := pitches || jsonb_build_array(pitch - 'comment' - 'proJurors' - 'pedJurors');
      else
        pitches := pitches || jsonb_build_array(null);
      end if;
    end loop;
    teams := teams || jsonb_build_array(jsonb_build_object(
      'name',team->>'name','activity',team->>'activity',
      'joinedAt',coalesce((team->>'joinedAt')::integer,0),
      'pitches',pitches));
  end loop;
  return jsonb_build_object('teams',teams);
end;
$$;
revoke all on function public.tfactory_v18_live_state() from public;
grant execute on function public.tfactory_v18_live_state() to anon, authenticated;

-- Vérification : six équipes attendues après l'importation historique.
select jsonb_array_length(data->'teams') as nombre_equipes
from public.tfactory_v18_state where id=1;

-- T·Factory V18 : à exécuter dans SQL Editor AVANT de déployer V18.
create extension if not exists pgcrypto with schema extensions;
create table if not exists public.tfactory_v18_jurors (
 id uuid primary key default gen_random_uuid(), pitch integer not null check(pitch between 0 and 7),
 name text not null check(length(trim(name)) between 1 and 80),
 category text not null check(category in ('pro','ped')),
 code_hash text not null unique, code_fingerprint text not null unique, created_at timestamptz not null default now()
);
create table if not exists public.tfactory_v18_jury_entries (
 juror_id uuid not null references public.tfactory_v18_jurors(id) on delete cascade,
 team_index integer not null check(team_index between 0 and 100),
 fond numeric not null check(fond>=0 and fond<=12),
 forme numeric not null check(forme>=0 and forme<=12),
 amount numeric not null check(amount>=0 and amount<=1000000),
 comment text not null default '' check(length(comment)<=2000),
 updated_at timestamptz not null default now(),
 primary key(juror_id,team_index)
);
create table if not exists public.tfactory_v18_jury_attempts (
 id bigint generated always as identity primary key,
 attempted_at timestamptz not null default now()
);
alter table public.tfactory_v18_jurors enable row level security;
alter table public.tfactory_v18_jury_entries enable row level security;
alter table public.tfactory_v18_jury_attempts enable row level security;
grant select,insert,delete on public.tfactory_v18_jurors to authenticated;
grant select,update,delete on public.tfactory_v18_jury_entries to authenticated;
create policy "admin jurors select" on public.tfactory_v18_jurors for select to authenticated using (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())));
create policy "admin jurors insert" on public.tfactory_v18_jurors for insert to authenticated with check (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())));
create policy "admin jurors delete" on public.tfactory_v18_jurors for delete to authenticated using (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())));
create policy "admin entries select" on public.tfactory_v18_jury_entries for select to authenticated using (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())));
create policy "admin entries update" on public.tfactory_v18_jury_entries for update to authenticated using (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid()))) with check (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())));
create policy "admin entries delete" on public.tfactory_v18_jury_entries for delete to authenticated using (exists(select 1 from public.tfactory_admins a where a.user_id=(select auth.uid())));
-- Aucun accès direct aux codes, aux jurés ou aux évaluations pour le public.
revoke all on public.tfactory_v18_jurors,public.tfactory_v18_jury_entries,public.tfactory_v18_jury_attempts from anon;
-- Enregistrement d'un code à cinq chiffres ; le code brut n'est pas stocké.
create or replace function public.tfactory_v18_add_juror(p_pitch integer,p_name text,p_category text,p_code text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not exists(select 1 from public.tfactory_admins where user_id=auth.uid()) then raise exception 'Administrateur requis';end if;
 if p_code !~ '^[0-9]{5}$' then raise exception 'Code invalide';end if;
 insert into public.tfactory_v18_jurors(pitch,name,category,code_hash,code_fingerprint)
 values(p_pitch,trim(p_name),p_category,extensions.crypt(p_code,extensions.gen_salt('bf')),encode(extensions.digest(p_code,'sha256'),'hex'))
 returning id into v_id;
 return v_id;
end $$;
-- Vérification du code et enregistrement côté serveur. Pas de lecture publique des codes.
create or replace function public.tfactory_v18_jury_action(p_code text,p_action text,p_team integer default null,p_fond numeric default null,p_forme numeric default null,p_amount numeric default null,p_comment text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare j public.tfactory_v18_jurors%rowtype; v_data jsonb; v_teams jsonb; v_count integer; v_existing boolean;
begin
 -- Plafond global conservateur de tentatives par minute : ralentit les essais automatisés.
 if (select count(*) from public.tfactory_v18_jury_attempts where attempted_at>now()-interval '1 minute')>=50 then raise exception 'Trop de tentatives. Réessayez dans une minute.';end if;
 insert into public.tfactory_v18_jury_attempts default values;
 if p_code !~ '^[0-9]{5}$' then raise exception 'Code invalide';end if;
 select * into j from public.tfactory_v18_jurors where code_fingerprint=encode(extensions.digest(p_code,'sha256'),'hex') and code_hash=extensions.crypt(p_code,code_hash) limit 1;
 if j.id is null then raise exception 'Code inconnu';end if;
 select data into v_data from public.tfactory_v18_state where id=1;
 v_teams:=coalesce(v_data->'teams','[]'::jsonb);v_count:=jsonb_array_length(v_teams);
 if p_action='info' then
   return jsonb_build_object('name',j.name,'category',j.category,'pitch',j.pitch,'teams',(
      select coalesce(jsonb_agg(jsonb_build_object('index',x.i-1,'name',x.t->>'name','activity',x.t->>'activity','entry',
        (select jsonb_build_object('fond',e.fond,'forme',e.forme,'amount',e.amount,'comment',e.comment) from public.tfactory_v18_jury_entries e where e.juror_id=j.id and e.team_index=x.i-1)) order by x.i),'[]'::jsonb)
      from jsonb_array_elements(v_teams) with ordinality x(t,i) where coalesce((x.t->>'joinedAt')::integer,0)<=j.pitch));
 elsif p_action='save' then
   if p_team is null or p_team<0 or p_team>=v_count or coalesce((v_teams->p_team->>'joinedAt')::integer,0)>j.pitch then raise exception 'Équipe invalide';end if;
   if coalesce((v_teams->p_team->'pitches'->j.pitch->>'locked')::boolean,false) then raise exception 'Pitch déjà publié : demander une correction à l’administrateur';end if;
   if p_fond is null or p_forme is null or p_amount is null or p_fond<0 or p_forme<0 or p_amount<0 or p_amount>1000000 or
      (j.category='pro' and (p_fond>8 or p_forme>12)) or (j.category='ped' and (p_fond>12 or p_forme>8)) then raise exception 'Notes ou financement hors limites';end if;
   insert into public.tfactory_v18_jury_entries(juror_id,team_index,fond,forme,amount,comment)
   values(j.id,p_team,p_fond,p_forme,p_amount,left(coalesce(p_comment,''),2000))
   on conflict(juror_id,team_index) do update set fond=excluded.fond,forme=excluded.forme,amount=excluded.amount,comment=excluded.comment,updated_at=now();
   return jsonb_build_object('ok',true);
 else raise exception 'Action invalide';end if;
end $$;
revoke all on function public.tfactory_v18_add_juror(integer,text,text,text) from public;
revoke all on function public.tfactory_v18_jury_action(text,text,integer,numeric,numeric,numeric,text) from public;
grant execute on function public.tfactory_v18_add_juror(integer,text,text,text) to authenticated;
grant execute on function public.tfactory_v18_jury_action(text,text,integer,numeric,numeric,numeric,text) to anon,authenticated;
-- Réinitialisation des jurés et des saisies individuelles pour un pitch, réservée à l'administrateur.
create or replace function public.tfactory_v18_reset_jury_pitch(p_pitch integer)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.tfactory_admins where user_id=auth.uid()) then raise exception 'Administrateur requis';end if;
 delete from public.tfactory_v18_jurors where pitch=p_pitch;
end $$;
revoke all on function public.tfactory_v18_reset_jury_pitch(integer) from public;
grant execute on function public.tfactory_v18_reset_jury_pitch(integer) to authenticated;

-- Vérification finale :
select jsonb_array_length(data->'teams') as nombre_equipes_v18 from public.tfactory_v18_state where id=1;
