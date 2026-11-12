-- CareMatch MVP database setup
-- Run the entire script in Supabase Dashboard > SQL Editor > New query.
-- This script is designed for a fresh Supabase project.

create extension if not exists pgcrypto;

-- 1. Accounts and roles
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('pending','candidate','employer','admin')),
  full_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Automatically create a profile after email sign-up. Role is selected in the app afterwards.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, role, full_name)
  values (
    new.id,
    case when new.raw_user_meta_data ->> 'role' in ('candidate','employer') then new.raw_user_meta_data ->> 'role' else 'pending' end,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create table public.candidates (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  phone text,
  town text not null,
  postcode text,
  travel_radius integer not null default 10 check (travel_radius between 1 and 100),
  experience_years integer not null default 0 check (experience_years between 0 and 60),
  employment_type text not null default 'any',
  summary text,
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.employers (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  company_name text not null,
  town text,
  postcode text,
  created_at timestamptz not null default now()
);

-- 2. Shared skill catalogue. IDs are stable slugs used by the frontend.
create table public.skills (
  id text primary key,
  label text not null,
  category text not null default 'Care skills',
  active boolean not null default true
);

insert into public.skills (id,label,category) values
('Personal care','Personal care','Core care'),
('Medication administration','Medication administration','Clinical and medication'),
('Dementia care','Dementia care','Specialist care'),
('Moving and handling','Moving and handling','Core care'),
('Safeguarding adults','Safeguarding adults','Safety and compliance'),
('End of life care','End of life care','Specialist care'),
('Live-in support','Live-in support','Care delivery'),
('Meal preparation','Meal preparation','Daily living'),
('Infection prevention','Infection prevention','Safety and compliance'),
('Companionship','Companionship','Daily living'),
('Learning disabilities','Learning disabilities','Specialist care'),
('Mental health support','Mental health support','Specialist care'),
('Catheter care','Catheter care','Clinical and medication'),
('PEG feeding','PEG feeding','Clinical and medication'),
('Record keeping','Record keeping','Core care')
on conflict (id) do update set label=excluded.label, category=excluded.category;

create table public.candidate_skills (
  candidate_id uuid not null references public.candidates(user_id) on delete cascade,
  skill_id text not null references public.skills(id),
  created_at timestamptz not null default now(),
  primary key (candidate_id, skill_id)
);

-- 3. Vacancies and required skills
create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text not null,
  town text not null,
  postcode text,
  employment_type text not null default 'Full-time',
  hourly_rate numeric(7,2) check (hourly_rate is null or hourly_rate >= 0),
  min_experience integer not null default 0 check (min_experience between 0 and 60),
  status text not null default 'draft' check (status in ('draft','published','paused','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.job_skills (
  job_id uuid not null references public.jobs(id) on delete cascade,
  skill_id text not null references public.skills(id),
  is_required boolean not null default true,
  primary key (job_id, skill_id)
);

-- 4. Applications and shortlists
create table public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  candidate_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'received' check (status in ('received','reviewing','interview','unsuccessful','hired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(job_id,candidate_id)
);

create table public.shortlists (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid not null references public.profiles(id) on delete cascade,
  candidate_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(employer_id,candidate_id),
  check (employer_id <> candidate_id)
);

create index jobs_employer_status_idx on public.jobs(employer_id,status);
create index jobs_status_created_idx on public.jobs(status,created_at desc);
create index applications_candidate_idx on public.applications(candidate_id,created_at desc);
create index candidate_skills_skill_idx on public.candidate_skills(skill_id);

-- 5. Updated-at helper
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
create trigger candidates_updated_at before update on public.candidates for each row execute function public.set_updated_at();
create trigger jobs_updated_at before update on public.jobs for each row execute function public.set_updated_at();
create trigger applications_updated_at before update on public.applications for each row execute function public.set_updated_at();
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();

-- Users may choose candidate or employer once; they cannot promote themselves to admin or switch roles later.
create or replace function public.protect_profile_role()
returns trigger language plpgsql as $$
begin
  if auth.uid() is not null then
    if old.role <> 'pending' and new.role <> old.role then raise exception 'Account type cannot be changed. Contact support.'; end if;
    if old.role = 'pending' and new.role not in ('candidate','employer') then raise exception 'Choose a valid account type.'; end if;
  end if;
  return new;
end;
$$;
create trigger protect_profile_role_before_update before update of role on public.profiles for each row execute function public.protect_profile_role();

-- 6. Row Level Security
alter table public.profiles enable row level security;
alter table public.candidates enable row level security;
alter table public.employers enable row level security;
alter table public.skills enable row level security;
alter table public.candidate_skills enable row level security;
alter table public.jobs enable row level security;
alter table public.job_skills enable row level security;
alter table public.applications enable row level security;
alter table public.shortlists enable row level security;

-- Profiles: users can see/edit their own profile. Employers can see a candidate's name only
-- when that candidate has applied to one of their jobs or is on their shortlist.
create policy "profiles_select_own_or_recruitment_relationship" on public.profiles for select to authenticated
using (
  id = auth.uid()
  or exists (select 1 from public.applications a join public.jobs j on j.id=a.job_id where a.candidate_id=profiles.id and j.employer_id=auth.uid())
  or exists (select 1 from public.shortlists s where s.candidate_id=profiles.id and s.employer_id=auth.uid())
);
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check (id=auth.uid() and role in ('pending','candidate','employer'));
create policy "profiles_update_own" on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());

create policy "candidate_manage_own" on public.candidates for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy "employer_manage_own" on public.employers for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy "skills_read_authenticated" on public.skills for select to authenticated using (active=true);
create policy "candidate_skills_manage_own" on public.candidate_skills for all to authenticated using (candidate_id=auth.uid()) with check (candidate_id=auth.uid());

create policy "jobs_read_published_or_own" on public.jobs for select to authenticated using (status='published' or employer_id=auth.uid());
create policy "jobs_insert_own_employer" on public.jobs for insert to authenticated with check (employer_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='employer'));
create policy "jobs_update_own" on public.jobs for update to authenticated using (employer_id=auth.uid()) with check (employer_id=auth.uid());
create policy "jobs_delete_own" on public.jobs for delete to authenticated using (employer_id=auth.uid());

create policy "job_skills_read_visible_job" on public.job_skills for select to authenticated using (exists(select 1 from public.jobs j where j.id=job_id and (j.status='published' or j.employer_id=auth.uid())));
create policy "job_skills_manage_own_job" on public.job_skills for all to authenticated using (exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid())) with check (exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid()));

create policy "applications_candidate_read" on public.applications for select to authenticated using (candidate_id=auth.uid());
create policy "applications_candidate_insert" on public.applications for insert to authenticated with check (candidate_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='candidate') and exists(select 1 from public.jobs j where j.id=job_id and j.status='published'));
create policy "applications_employer_read" on public.applications for select to authenticated using (exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid()));
create policy "applications_employer_update" on public.applications for update to authenticated using (exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid())) with check (exists(select 1 from public.jobs j where j.id=job_id and j.employer_id=auth.uid()));

create policy "shortlists_employer_manage_own" on public.shortlists for all to authenticated using (employer_id=auth.uid()) with check (employer_id=auth.uid() and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='employer'));

-- 7. Matching RPC. Candidate personal contact details are deliberately not returned.
-- Weights: skills 70%, experience 20%, town match 10%.
-- Location is an exact town comparison in this MVP, NOT a distance calculation.
create or replace function public.match_candidates(p_job_id uuid)
returns table (
  candidate_id uuid,
  full_name text,
  town text,
  experience_years integer,
  summary text,
  match_score integer,
  matched_skills text[],
  missing_required text[]
)
language plpgsql
security definer
set search_path = public
as $$
declare v_job public.jobs%rowtype;
begin
  if auth.uid() is null then raise exception 'You must be logged in.'; end if;
  if not exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='employer') then
    raise exception 'Only employer accounts can view candidate matches.';
  end if;
  select * into v_job from public.jobs j where j.id=p_job_id and j.employer_id=auth.uid() and j.status='published';
  if not found then raise exception 'Published vacancy not found or you do not have access.'; end if;

  return query
  with job_skill_set as (
    select js.skill_id, s.label, js.is_required
    from public.job_skills js join public.skills s on s.id=js.skill_id
    where js.job_id=p_job_id
  ), candidate_rows as (
    select c.user_id, p.full_name, c.town, c.experience_years, c.summary,
      coalesce(array_agg(distinct jss.label) filter (where jss.label is not null and cs.skill_id is not null), '{}') as matched,
      coalesce(array_agg(distinct jss.label) filter (where jss.label is not null and jss.is_required=true and cs.skill_id is null), '{}') as missing,
      count(jss.skill_id) filter (where jss.is_required=true) as required_count,
      count(jss.skill_id) filter (where jss.is_required=true and cs.skill_id is not null) as required_matched
    from public.candidates c
    join public.profiles p on p.id=c.user_id
    left join job_skill_set jss on true
    left join public.candidate_skills cs on cs.candidate_id=c.user_id and cs.skill_id=jss.skill_id
    where c.is_visible=true and c.user_id<>auth.uid()
    group by c.user_id,p.full_name,c.town,c.experience_years,c.summary
  )
  select cr.user_id,cr.full_name,cr.town,cr.experience_years,cr.summary,
    least(100, greatest(0, round(
      (case when cr.required_count=0 then 70.0 else (cr.required_matched::numeric/cr.required_count)*70.0 end)
      + (case when v_job.min_experience=0 then 20.0 else least(cr.experience_years::numeric/v_job.min_experience,1.0)*20.0 end)
      + (case when lower(trim(coalesce(cr.town,'')))=lower(trim(v_job.town)) then 10.0 else 0.0 end)
    )::integer)), cr.matched, cr.missing
  from candidate_rows cr
  order by 6 desc, cr.experience_years desc;
end;
$$;
revoke all on function public.match_candidates(uuid) from public;
grant execute on function public.match_candidates(uuid) to authenticated;

-- Helpful note: this starter is intended for a fresh project. Review policies before production use.
