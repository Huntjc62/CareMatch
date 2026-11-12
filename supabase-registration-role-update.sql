-- CareMatch: apply this once to an EXISTING Supabase project.
-- It updates the auth trigger so new registrations save the selected account type.
-- Existing users with role='pending' can still choose their type when they next log in.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, role, full_name)
  values (
    new.id,
    case
      when new.raw_user_meta_data ->> 'role' in ('candidate', 'employer')
        then new.raw_user_meta_data ->> 'role'
      else 'pending'
    end,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
