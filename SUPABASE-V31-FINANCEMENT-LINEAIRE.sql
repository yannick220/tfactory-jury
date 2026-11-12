-- Mise à jour V19 : à exécuter UNE FOIS dans le projet Supabase T-Factory.
-- N’efface ni les équipes ni les évaluations existantes.
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
   -- Financement strictement lineaire : 300 EUR par point /20.
   -- Petite tolerance pour la representation numerique, sans arrondi des notes.
   if abs(p_amount - (p_fond+p_forme)*300) > 0.02 then
      raise exception 'Financement incoherent avec la note (note x 300 EUR)';
   end if;
   insert into public.tfactory_v18_jury_entries(juror_id,team_index,fond,forme,amount,comment)
   values(j.id,p_team,p_fond,p_forme,p_amount,left(coalesce(p_comment,''),2000))
   on conflict(juror_id,team_index) do update set fond=excluded.fond,forme=excluded.forme,amount=excluded.amount,comment=excluded.comment,updated_at=now();
   return jsonb_build_object('ok',true);
 else raise exception 'Action invalide';end if;
end $$;
