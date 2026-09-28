create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, role, full_name, phone, city, state)
  values (
    new.id,
    case
      when (new.raw_app_meta_data ->> 'role') in ('empresa','candidato','admin')
        then (new.raw_app_meta_data ->> 'role')::public.app_role
      else 'candidato'::public.app_role
    end,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(coalesce(new.email,''),'@',1), 'Novo usuário'),
    new.phone,
    new.raw_user_meta_data ->> 'city',
    coalesce(new.raw_user_meta_data ->> 'state','RS')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
