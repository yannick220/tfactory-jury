-- T·Factory V24 — renouvellement sécurisé d’un code juré.
-- À exécuter UNE FOIS dans Supabase SQL Editor (projet Jury).
-- Ne modifie ni les notes, ni les montants, ni la V17.
create or replace function public.tfactory_v18_regenerate_juror_code(p_juror_id uuid, p_code text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists (select 1 from public.tfactory_admins where user_id=auth.uid()) then
  raise exception 'Administrateur requis';
 end if;
 if p_code is null or p_code !~ '^[0-9]{5}$' then
  raise exception 'Code invalide';
 end if;
 update public.tfactory_v18_jurors
 set code_hash=extensions.crypt(p_code,extensions.gen_salt('bf')),
     code_fingerprint=encode(extensions.digest(p_code,'sha256'),'hex')
 where id=p_juror_id;
 if not found then raise exception 'Juré introuvable'; end if;
end $$;
revoke all on function public.tfactory_v18_regenerate_juror_code(uuid,text) from public;
grant execute on function public.tfactory_v18_regenerate_juror_code(uuid,text) to authenticated;
