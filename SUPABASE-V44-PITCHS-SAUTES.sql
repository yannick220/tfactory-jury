-- T·Factory V44 — remplacement sécurisé de la fonction V43 : un pitch sauté ne peut pas être publié automatiquement.
-- À exécuter dans Supabase SQL Editor APRÈS V43.
-- T·Factory V43 — publication automatique des pitchs
-- À exécuter UNE FOIS dans le SQL Editor du projet Supabase existant.
-- Ne supprime ni les jurés, ni les notes, ni les résultats déjà publiés.
-- Le déclenchement est transactionnel : dernier enregistrement valide -> publication.

create or replace function public.tfactory_v18_autopublish_pitch(p_pitch integer)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_data jsonb;
  v_teams jsonb;
  v_total integer;
  v_team_index integer;
  v_jurors integer;
  v_pro integer;
  v_ped integer;
  v_expected integer;
  v_entries integer;
  v_scores jsonb;
  v_pro_rows jsonb;
  v_ped_rows jsonb;
  v_jury_amounts jsonb;
  v_comments text;
  v_amount numeric;
  v_new jsonb;
begin
  if p_pitch not between 0 and 7 then return false; end if;
  -- Verrouille l'état pour éviter deux publications concurrentes.
  select data into v_data from public.tfactory_v18_state where id=1 for update;
  if v_data is null then return false; end if;
  if coalesce(v_data->'skippedPitches','[]'::jsonb) @> jsonb_build_array(p_pitch) then return false; end if;
  v_teams:=coalesce(v_data->'teams','[]'::jsonb);
  v_total:=jsonb_array_length(v_teams);
  select count(*),count(*) filter(where category='pro'),count(*) filter(where category='ped')
    into v_jurors,v_pro,v_ped
    from public.tfactory_v18_jurors where pitch=p_pitch;
  if v_pro=0 or v_ped=0 then return false; end if;
  select count(*) into v_expected
    from jsonb_array_elements(v_teams) t
    where coalesce((t->>'joinedAt')::integer,0)<=p_pitch;
  if v_expected=0 then return false; end if;
  -- Ne jamais remplacer un résultat déjà publié ou partiellement verrouillé.
  if exists(
    select 1 from jsonb_array_elements(v_teams) t
    where coalesce((t->>'joinedAt')::integer,0)<=p_pitch
      and coalesce((t->'pitches'->p_pitch->>'locked')::boolean,false)
  ) then return false; end if;
  select count(*) into v_entries
    from public.tfactory_v18_jury_entries e
    join public.tfactory_v18_jurors j on j.id=e.juror_id
    where j.pitch=p_pitch and e.team_index>=0 and e.team_index<v_total
      and coalesce((v_teams->e.team_index->>'joinedAt')::integer,0)<=p_pitch;
  if v_entries<>v_jurors*v_expected then return false; end if;
  -- Construire exactement les mêmes scores, allocations et commentaires
  -- que la publication manuelle de V42.
  for v_team_index in 0..v_total-1 loop
    if coalesce((v_teams->v_team_index->>'joinedAt')::integer,0)>p_pitch then continue; end if;
    select jsonb_build_array(
      avg(e.fond) filter(where j.category='pro'),
      avg(e.forme) filter(where j.category='pro'),
      avg(e.fond) filter(where j.category='ped'),
      avg(e.forme) filter(where j.category='ped')
    ),
    coalesce(jsonb_agg(jsonb_build_array(e.fond,e.forme) order by j.created_at,j.id) filter(where j.category='pro'),'[]'::jsonb),
    coalesce(jsonb_agg(jsonb_build_array(e.fond,e.forme) order by j.created_at,j.id) filter(where j.category='ped'),'[]'::jsonb),
    coalesce(jsonb_agg(jsonb_build_object('name',j.name,'category',j.category,'amount',least(6000,greatest(0,e.fond+e.forme)*300)) order by j.created_at,j.id),'[]'::jsonb),
    coalesce(string_agg(j.name||' : '||e.comment,E'\n' order by j.created_at,j.id) filter(where e.comment<>''),''),
    ceil((avg(least(6000,greatest(0,e.fond+e.forme)*300))-0.000000001)/10)*10
    into v_scores,v_pro_rows,v_ped_rows,v_jury_amounts,v_comments,v_amount
    from public.tfactory_v18_jury_entries e
    join public.tfactory_v18_jurors j on j.id=e.juror_id
    where j.pitch=p_pitch and e.team_index=v_team_index;
    if jsonb_array_length(v_pro_rows)<>v_pro or jsonb_array_length(v_ped_rows)<>v_ped then return false; end if;
    v_new:=jsonb_build_object('scores',v_scores,'proJurors',v_pro_rows,'pedJurors',v_ped_rows,
      'amount',v_amount,'locked',true,'comment',v_comments,'juryAmounts',v_jury_amounts);
    v_data:=jsonb_set(v_data,array['teams',v_team_index::text,'pitches',p_pitch::text],v_new,true);
  end loop;
  update public.tfactory_v18_state set data=v_data where id=1;
  return true;
end;
$$;
revoke all on function public.tfactory_v18_autopublish_pitch(integer) from public;
-- La fonction est invoquée uniquement par le trigger, jamais directement par le navigateur.

create or replace function public.tfactory_v18_autopublish_on_entry()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_pitch integer;
begin
  select pitch into v_pitch from public.tfactory_v18_jurors where id=new.juror_id;
  if v_pitch is not null then
    perform public.tfactory_v18_autopublish_pitch(v_pitch);
  end if;
  return new;
end;
$$;

drop trigger if exists tfactory_v18_auto_publish_after_entry on public.tfactory_v18_jury_entries;
create trigger tfactory_v18_auto_publish_after_entry
  after insert or update on public.tfactory_v18_jury_entries
  for each row execute function public.tfactory_v18_autopublish_on_entry();

-- Si les jurés avaient déjà tous saisi leurs notes avant l'installation,
-- publier les pitchs complets non publiés immédiatement.
do $$ declare p integer; begin
  for p in 0..7 loop
    perform public.tfactory_v18_autopublish_pitch(p);
  end loop;
end $$;

-- Contrôle de présence du trigger :
select tgname as declencheur_installe from pg_trigger
where tgrelid='public.tfactory_v18_jury_entries'::regclass
and tgname='tfactory_v18_auto_publish_after_entry' and not tgisinternal;
