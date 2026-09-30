-- IBGE official code table: https://www.ibge.gov.br/explica/codigos-dos-municipios.php
-- Boa Esperança do Norte was installed on 2025-01-01; preserve all existing codes.
insert into public.brazil_cities(ibge_code,name,uf_code,uf) values(5101837,'Boa Esperança do Norte',51,'MT')
on conflict(ibge_code) do update set name=excluded.name,uf_code=excluded.uf_code,uf=excluded.uf;
create or replace function public.normalize_city_name(p_value text)
returns text language sql immutable strict security invoker set search_path='' as $$
 select lower(translate(trim(p_value),'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç','AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc'));
$$;
alter table public.brazil_cities add column if not exists normalized_name text generated always as (public.normalize_city_name(name)) stored;
create index if not exists brazil_cities_normalized_name_idx on public.brazil_cities(normalized_name text_pattern_ops,uf);
create or replace function public.resolve_brazil_city(p_city text)
returns integer language sql stable security invoker set search_path='' as $$
 with candidates as (
 select ibge_code from public.brazil_cities
 where public.normalize_city_name(name||' — '||trim(uf))=public.normalize_city_name(p_city)
    or public.normalize_city_name(name||' - '||trim(uf))=public.normalize_city_name(p_city)
    or normalized_name=public.normalize_city_name(p_city)
 ) select case when count(*)=1 then min(ibge_code) end from candidates;
$$;
revoke all on function public.normalize_city_name(text), public.resolve_brazil_city(text) from public;
grant execute on function public.normalize_city_name(text), public.resolve_brazil_city(text) to anon,authenticated;

create or replace function public.enforce_canonical_city()
returns trigger language plpgsql security invoker set search_path='' as $$
declare v_code integer; v_city public.brazil_cities; v_changed boolean;
begin
 if tg_op='UPDATE' then
   v_changed:=new.city is distinct from old.city or new.city_ibge_code is distinct from old.city_ibge_code;
   if not v_changed then return new; end if;
 else v_changed:=true; end if;
 if nullif(trim(new.city),'') is null and new.city_ibge_code is null then return new; end if;
 if new.city_ibge_code is not null and (tg_op='INSERT' or new.city_ibge_code is distinct from old.city_ibge_code) then
   v_code:=new.city_ibge_code;
 else v_code:=public.resolve_brazil_city(new.city); end if;
 if v_code is null then raise exception 'Selecione município e UF na lista oficial do IBGE'; end if;
 select * into v_city from public.brazil_cities where ibge_code=v_code;
 if not found then raise exception 'Código IBGE inválido'; end if;
 new.city_ibge_code:=v_code;
 new.city:=v_city.name||' — '||trim(v_city.uf);
 if to_jsonb(new) ? 'state' then
   new:=jsonb_populate_record(new,jsonb_build_object('state',trim(v_city.uf)));
 end if;
 return new;
end $$;
revoke all on function public.enforce_canonical_city() from public,anon,authenticated;
do $$ declare t text; begin
 foreach t in array array['profiles','candidate_profiles','companies','jobs','job_alerts'] loop
   execute format('alter table public.%I add column if not exists city_ibge_code integer references public.brazil_cities(ibge_code)',t);
   -- Only unambiguous legacy values are mapped. Unresolved text is preserved for later review.
   execute format('update public.%I set city_ibge_code=public.resolve_brazil_city(city) where city_ibge_code is null and city is not null',t);
   execute format('create index if not exists %I on public.%I(city_ibge_code)',t||'_city_ibge_idx',t);
   execute format('drop trigger if exists enforce_canonical_city on public.%I',t);
   execute format('create trigger enforce_canonical_city before insert or update of city,city_ibge_code on public.%I for each row execute function public.enforce_canonical_city()',t);
 end loop;
end $$;
