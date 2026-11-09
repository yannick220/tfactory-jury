-- T·Factory Jury V20 : suppression individuelle des jurés.
-- À exécuter dans le projet Supabase existant, sans supprimer les données V17.
-- Les évaluations associées sont supprimées automatiquement (ON DELETE CASCADE).
create or replace function public.tfactory_v18_delete_juror(p_juror_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists (select 1 from public.tfactory_admins where user_id=auth.uid()) then
  raise exception 'Administrateur requis';
 end if;
 delete from public.tfactory_v18_jurors where id=p_juror_id;
 if not found then raise exception 'Juré introuvable'; end if;
end $$;
revoke all on function public.tfactory_v18_delete_juror(uuid) from public;
grant execute on function public.tfactory_v18_delete_juror(uuid) to authenticated;
