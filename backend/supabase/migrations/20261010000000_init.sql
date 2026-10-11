-- Wheelio V1 schema. Ready to apply to a new Supabase project:
--   supabase link --project-ref <ref> && supabase db push
-- Region: ap-south-1 (Mumbai). Money is stored in paise (integer).
-- Business rules that are still open decisions live in app_settings so they
-- can change without a migration.

create extension if not exists postgis;
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Settings (open decisions from the roadmap)

create table public.app_settings (
  key text primary key,
  value jsonb not null,
  note text
);

insert into public.app_settings (key, value, note) values
  ('approval_window_minutes', '120', 'Proposed: about 2 hours (F14)'),
  ('dispute_window_minutes', '1440', 'Proposed: 24 hours after approval (F16)'),
  ('washer_share_pct', '78', 'Proposed split, 9 Oct 2026'),
  ('late_penalty_paise_per_min', '100', 'Agreed: Rs 1 per minute'),
  ('late_penalty_cap_pct', '30', 'Proposed cap, needs sign-off'),
  ('cancellation_fee_paise', 'null', '[CANCELLATION FEE] not decided'),
  ('wait_fee_paise', 'null', '[WAIT FEE] not decided'),
  ('accept_timeout_seconds', '15', 'Washer job alert'),
  ('minutes_per_wash', '20', 'Used for job chaining'),
  ('protection_fund_paise_per_wash', '150', 'Rs 1 to 2 per wash');

-- ---------------------------------------------------------------------------
-- Catalogue

create table public.vehicle_types (
  kind text primary key check (kind in ('bike', 'hatchback', 'sedan', 'suv')),
  name text not null,
  minutes int not null,
  price_paise int not null check (price_paise > 0),
  sort int not null default 0,
  active boolean not null default true
);

insert into public.vehicle_types (kind, name, minutes, price_paise, sort) values
  ('bike', 'Bike or scooter', 15, 6900, 1),
  ('hatchback', 'Hatchback', 20, 14900, 2),
  ('sedan', 'Sedan or compact SUV', 20, 17900, 3),
  ('suv', 'SUV or MUV', 25, 21900, 4);

create table public.societies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  area text not null,
  city text not null default 'Hyderabad',
  pincode text,
  location geography(point, 4326),
  is_live boolean not null default false,
  created_at timestamptz not null default now()
);
create index societies_location_idx on public.societies using gist (location);
create index societies_name_idx on public.societies using gin (to_tsvector('simple', name || ' ' || area));

-- Wash windows offered per society per day; capacity comes from washers on shift.
create table public.slot_templates (
  id serial primary key,
  start_hour int not null check (start_hour between 0 and 23),
  end_hour int not null check (end_hour between 1 and 24 and end_hour > start_hour)
);
insert into public.slot_templates (start_hour, end_hour) values (6, 8), (8, 10), (10, 12), (12, 14), (14, 16), (16, 18);

-- ---------------------------------------------------------------------------
-- People

create table public.customers (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text not null unique,
  name text not null default '',
  free_washes int not null default 0 check (free_washes >= 0),
  notifications_on boolean not null default false,
  push_token text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create type public.washer_status as enum ('onboarding', 'under_review', 'probation', 'active', 'paused', 'removed');

create table public.washers (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text not null unique,
  name text not null default '',
  language text not null default 'hi' check (language in ('hi', 'te', 'en')),
  status public.washer_status not null default 'onboarding',
  kyc_ref text,                      -- DigiLocker / KYC provider reference, never the Aadhaar number
  face_hash text,                    -- for blacklist matching (roadmap safeguard)
  payout_ref text,                   -- Razorpay linked account id
  probation_day int not null default 0,
  daily_limit int not null default 2,
  rating numeric(3, 2) not null default 0,
  washes int not null default 0,
  refresher_due_at timestamptz,
  online boolean not null default false,
  last_location geography(point, 4326),
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);
create index washers_location_idx on public.washers using gist (last_location);

create table public.washer_societies (
  washer_id uuid references public.washers (id) on delete cascade,
  society_id uuid references public.societies (id) on delete cascade,
  primary key (washer_id, society_id)
);

create table public.admins (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null
);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where id = auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- Vehicles and places

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers (id) on delete cascade,
  plate text not null,
  kind text not null references public.vehicle_types (kind),
  society_id uuid references public.societies (id),
  tower text not null default '',
  floor text,
  slot text not null default '',
  created_at timestamptz not null default now(),
  unique (customer_id, plate)
);

-- ---------------------------------------------------------------------------
-- Orders

create type public.order_status as enum (
  'pending_payment', 'payment_pending', 'searching', 'on_the_way', 'washing', 'photos_ready',
  'approved', 'auto_approved', 'disputed', 'dispute_upheld', 'dispute_rejected', 'cancelled', 'no_washer'
);

create sequence public.order_ref_seq start 20900;

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  ref text not null unique default ('WH-' || nextval('public.order_ref_seq')),
  customer_id uuid not null references public.customers (id),
  vehicle_id uuid not null references public.vehicles (id),
  society_id uuid not null references public.societies (id),
  tower text not null default '',
  floor text not null,
  slot text not null default '',
  location geography(point, 4326),
  slot_start timestamptz not null,
  slot_end timestamptz not null,
  price_paise int not null,
  used_free_wash boolean not null default false,
  note_text text not null default '',
  note_media_path text,              -- storage path of voice or video note
  status public.order_status not null default 'pending_payment',
  washer_id uuid references public.washers (id),
  accepted_at timestamptz,
  arrives_by timestamptz,
  running_late_minutes int,
  washer_cant_find boolean not null default false,
  entry_pass_received_at timestamptz,
  started_at timestamptz,
  finished_at timestamptz,
  auto_approve_at timestamptz,
  approved_at timestamptz,
  cancelled_at timestamptz,
  cancel_reason text,
  late_penalty_paise int not null default 0,
  created_at timestamptz not null default now(),
  check (slot_end > slot_start)
);
create index orders_customer_idx on public.orders (customer_id, slot_start desc);
create index orders_washer_idx on public.orders (washer_id, slot_start);
create index orders_open_idx on public.orders (status) where status in ('searching', 'on_the_way', 'washing', 'photos_ready');

-- Every status change, for the timeline, support and audits.
create table public.order_events (
  id bigserial primary key,
  order_id uuid not null references public.orders (id) on delete cascade,
  kind text not null,
  data jsonb not null default '{}',
  actor uuid,
  created_at timestamptz not null default now()
);
create index order_events_order_idx on public.order_events (order_id, created_at);

-- Customer identification photos (F02) and washer evidence photos.
create type public.photo_role as enum ('customer_id', 'before', 'after', 'dispute');

create table public.order_photos (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  role public.photo_role not null,
  angle text not null check (angle in ('front', 'back', 'left', 'right', 'closeup', 'video', 'other')),
  storage_path text not null,
  taken_at timestamptz not null,
  taken_lat double precision,
  taken_lng double precision,
  uploaded_by uuid not null,
  ai_check jsonb,                    -- result of the AI photo comparison
  created_at timestamptz not null default now()
);
create index order_photos_order_idx on public.order_photos (order_id, role);

create table public.entry_passes (
  order_id uuid primary key references public.orders (id) on delete cascade,
  source text not null default 'whatsapp',
  storage_path text,
  text_value text,
  received_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Money

create type public.payment_status as enum ('created', 'authorized', 'captured', 'failed', 'refunded', 'partially_refunded');

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id),
  provider text not null default 'razorpay',
  provider_order_id text unique,
  provider_payment_id text unique,
  method text,
  amount_paise int not null,
  status public.payment_status not null default 'created',
  raw jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id),
  payment_id uuid references public.payments (id),
  amount_paise int not null,
  reason text not null,
  provider_refund_id text,
  bank_ref text,
  status text not null default 'started' check (status in ('started', 'processed', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

-- Washer payouts, released after approval and paid before midnight.
create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  washer_id uuid not null references public.washers (id),
  order_id uuid not null unique references public.orders (id),
  gross_paise int not null,
  penalty_paise int not null default 0,
  net_paise int not null,
  status text not null default 'pending' check (status in ('pending', 'held', 'released', 'paid', 'reversed')),
  provider_transfer_id text,
  hold_reason text,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create table public.credits_ledger (
  id bigserial primary key,
  customer_id uuid not null references public.customers (id) on delete cascade,
  delta int not null,
  reason text not null,
  order_id uuid references public.orders (id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Quality

create table public.ratings (
  order_id uuid primary key references public.orders (id) on delete cascade,
  washer_id uuid not null references public.washers (id),
  stars int not null check (stars between 1 and 5),
  tags text[] not null default '{}',
  comment text not null default '',
  needs_review boolean not null default false,  -- clearly unfair low ratings go to a person
  created_at timestamptz not null default now()
);

create type public.dispute_kind as enum ('not_clean', 'damage', 'wrong_vehicle', 'no_show');
create type public.dispute_outcome as enum ('under_review', 'upheld', 'rejected', 'damage_priority');

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  ref text not null unique default ('WH-' || nextval('public.order_ref_seq')),
  order_id uuid not null references public.orders (id),
  kind public.dispute_kind not null,
  note text not null default '',
  outcome public.dispute_outcome not null default 'under_review',
  decision_note text not null default '',
  credits_awarded int not null default 0,
  ai_summary jsonb,
  decided_by uuid,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

-- Washer onboarding and training (phase 3, created now so the data model is complete).
create table public.training_videos (
  id uuid primary key default gen_random_uuid(),
  youtube_id text not null,          -- embedded with the official player only, never re-hosted
  language text not null check (language in ('hi', 'te', 'en')),
  vehicle_kind text,
  is_refresher boolean not null default false,
  sort int not null default 0
);

create table public.washer_training (
  washer_id uuid references public.washers (id) on delete cascade,
  video_id uuid references public.training_videos (id) on delete cascade,
  watched_at timestamptz not null default now(),
  primary key (washer_id, video_id)
);

create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  washer_id uuid not null references public.washers (id) on delete cascade,
  language text not null,
  score int not null,
  passed boolean not null,
  transcript jsonb,
  created_at timestamptz not null default now()
);

create table public.job_offers (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  washer_id uuid not null references public.washers (id) on delete cascade,
  offered_at timestamptz not null default now(),
  expires_at timestamptz not null,
  response text check (response in ('accepted', 'declined', 'missed')),
  responded_at timestamptz,
  unique (order_id, washer_id)
);

-- ---------------------------------------------------------------------------
-- Row level security. Customers see only their own rows; washers see only
-- jobs offered or assigned to them; admins see everything. Status changes go
-- through the security-definer functions below, never direct updates.

alter table public.customers enable row level security;
alter table public.washers enable row level security;
alter table public.vehicles enable row level security;
alter table public.orders enable row level security;
alter table public.order_events enable row level security;
alter table public.order_photos enable row level security;
alter table public.entry_passes enable row level security;
alter table public.payments enable row level security;
alter table public.refunds enable row level security;
alter table public.payouts enable row level security;
alter table public.credits_ledger enable row level security;
alter table public.ratings enable row level security;
alter table public.disputes enable row level security;
alter table public.job_offers enable row level security;
alter table public.washer_training enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.societies enable row level security;
alter table public.vehicle_types enable row level security;
alter table public.slot_templates enable row level security;
alter table public.training_videos enable row level security;
alter table public.app_settings enable row level security;
alter table public.admins enable row level security;
alter table public.washer_societies enable row level security;

create policy "catalogue readable" on public.vehicle_types for select using (true);
create policy "societies readable" on public.societies for select using (true);
create policy "slots readable" on public.slot_templates for select using (true);
create policy "settings readable" on public.app_settings for select using (true);
create policy "videos readable by washers" on public.training_videos for select using (auth.uid() is not null);

create policy "customer reads self" on public.customers for select using (id = auth.uid() or public.is_admin());
create policy "customer updates self" on public.customers for update using (id = auth.uid())
  with check (id = auth.uid());

create policy "washer reads self" on public.washers for select using (id = auth.uid() or public.is_admin());

create policy "customer vehicles" on public.vehicles for all using (customer_id = auth.uid())
  with check (customer_id = auth.uid());
create policy "admin vehicles" on public.vehicles for select using (public.is_admin());

create policy "customer orders" on public.orders for select using (customer_id = auth.uid());
create policy "washer orders" on public.orders for select using (washer_id = auth.uid());
create policy "admin orders" on public.orders for select using (public.is_admin());

create policy "order events visible with order" on public.order_events for select using (
  exists (select 1 from public.orders o where o.id = order_id
          and (o.customer_id = auth.uid() or o.washer_id = auth.uid() or public.is_admin())));

create policy "photos visible with order" on public.order_photos for select using (
  exists (select 1 from public.orders o where o.id = order_id
          and (o.customer_id = auth.uid() or o.washer_id = auth.uid() or public.is_admin())));

-- Entry pass is shared with the assigned washer only.
create policy "entry pass for assigned washer" on public.entry_passes for select using (
  exists (select 1 from public.orders o where o.id = order_id
          and (o.washer_id = auth.uid() or o.customer_id = auth.uid() or public.is_admin())));

create policy "customer payments" on public.payments for select using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or public.is_admin())));
create policy "customer refunds" on public.refunds for select using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or public.is_admin())));
create policy "washer payouts" on public.payouts for select using (washer_id = auth.uid() or public.is_admin());
create policy "customer credits" on public.credits_ledger for select using (customer_id = auth.uid() or public.is_admin());
create policy "ratings visible" on public.ratings for select using (
  washer_id = auth.uid() or public.is_admin() or
  exists (select 1 from public.orders o where o.id = order_id and o.customer_id = auth.uid()));
create policy "customer disputes" on public.disputes for select using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or public.is_admin())));
create policy "washer offers" on public.job_offers for select using (washer_id = auth.uid() or public.is_admin());
create policy "washer training" on public.washer_training for select using (washer_id = auth.uid() or public.is_admin());
create policy "washer quiz" on public.quiz_attempts for select using (washer_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- Helpers

create or replace function public.setting_int(k text) returns int
language sql stable as $$
  select nullif(value::text, 'null')::int from public.app_settings where key = k;
$$;

create or replace function public.log_event(p_order uuid, p_kind text, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.order_events (order_id, kind, data, actor) values (p_order, p_kind, p_data, auth.uid());
$$;

-- Create the customer row on first login (phone OTP through Supabase Auth).
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'app', 'customer') = 'customer' then
    insert into public.customers (id, phone) values (new.id, coalesce(new.phone, ''))
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Customer actions (called with supabase.rpc from the app)

create or replace function public.create_order(
  p_kind text, p_plate text, p_society uuid, p_tower text, p_floor text, p_slot text,
  p_slot_start timestamptz, p_slot_end timestamptz, p_note_text text default '',
  p_note_media_path text default null, p_use_free_wash boolean default false,
  p_lat double precision default null, p_lng double precision default null
) returns public.orders
language plpgsql security definer set search_path = public as $$
declare
  v_customer public.customers;
  v_vehicle uuid;
  v_price int;
  v_order public.orders;
begin
  select * into v_customer from public.customers where id = auth.uid() and deleted_at is null;
  if v_customer.id is null then raise exception 'not_logged_in'; end if;
  if p_floor is null or p_floor = '' then raise exception 'floor_required'; end if;
  if p_slot_start < now() - interval '30 minutes' then raise exception 'slot_in_past'; end if;
  if p_use_free_wash and v_customer.free_washes < 1 then raise exception 'no_free_washes'; end if;

  select price_paise into v_price from public.vehicle_types where kind = p_kind and active;
  if v_price is null then raise exception 'unknown_vehicle_type'; end if;

  insert into public.vehicles (customer_id, plate, kind, society_id, tower, floor, slot)
  values (auth.uid(), upper(p_plate), p_kind, p_society, p_tower, p_floor, p_slot)
  on conflict (customer_id, plate) do update
    set kind = excluded.kind, society_id = excluded.society_id, tower = excluded.tower,
        floor = excluded.floor, slot = excluded.slot
  returning id into v_vehicle;

  insert into public.orders (customer_id, vehicle_id, society_id, tower, floor, slot, location,
                             slot_start, slot_end, price_paise, used_free_wash, note_text, note_media_path)
  values (auth.uid(), v_vehicle, p_society, p_tower, p_floor, p_slot,
          case when p_lat is null then null else st_point(p_lng, p_lat)::geography end,
          p_slot_start, p_slot_end, v_price, p_use_free_wash, coalesce(p_note_text, ''), p_note_media_path)
  returning * into v_order;

  perform public.log_event(v_order.id, 'created');
  return v_order;
end;
$$;

create or replace function public.cancel_order(p_order uuid, p_reason text default null)
returns public.orders language plpgsql security definer set search_path = public as $$
declare
  v public.orders;
  v_fee int := 0;
begin
  select * into v from public.orders where id = p_order and customer_id = auth.uid() for update;
  if v.id is null then raise exception 'not_found'; end if;
  if v.status not in ('pending_payment', 'payment_pending', 'searching', 'on_the_way') then
    raise exception 'cannot_cancel_now';
  end if;
  if v.status = 'on_the_way' then v_fee := coalesce(public.setting_int('cancellation_fee_paise'), 0); end if;

  update public.orders set status = 'cancelled', cancelled_at = now(), cancel_reason = p_reason
  where id = p_order returning * into v;

  if exists (select 1 from public.payments where order_id = p_order and status in ('authorized', 'captured')) then
    insert into public.refunds (order_id, amount_paise, reason) values (p_order, v.price_paise - v_fee, 'customer_cancelled');
  end if;
  if v.used_free_wash then
    update public.customers set free_washes = free_washes + 1 where id = v.customer_id;
    insert into public.credits_ledger (customer_id, delta, reason, order_id) values (v.customer_id, 1, 'cancel_return', p_order);
  end if;
  perform public.log_event(p_order, 'cancelled', jsonb_build_object('reason', p_reason, 'fee_paise', v_fee));
  return v;
end;
$$;

create or replace function public.approve_order(p_order uuid)
returns public.orders language plpgsql security definer set search_path = public as $$
declare v public.orders;
begin
  update public.orders set status = 'approved', approved_at = now()
  where id = p_order and customer_id = auth.uid() and status = 'photos_ready'
  returning * into v;
  if v.id is null then raise exception 'cannot_approve'; end if;
  update public.payouts set status = 'released' where order_id = p_order and status = 'pending';
  perform public.log_event(p_order, 'approved');
  return v;
end;
$$;

create or replace function public.rate_order(p_order uuid, p_stars int, p_tags text[] default '{}', p_comment text default '')
returns void language plpgsql security definer set search_path = public as $$
declare v public.orders;
begin
  select * into v from public.orders where id = p_order and customer_id = auth.uid()
    and status in ('approved', 'auto_approved', 'dispute_rejected');
  if v.id is null then raise exception 'cannot_rate'; end if;
  insert into public.ratings (order_id, washer_id, stars, tags, comment, needs_review)
  values (p_order, v.washer_id, p_stars, p_tags, p_comment, p_stars <= 2)
  on conflict (order_id) do update set stars = excluded.stars, tags = excluded.tags, comment = excluded.comment;
  update public.washers w set rating = (select avg(stars) from public.ratings r where r.washer_id = w.id)
  where w.id = v.washer_id;
end;
$$;

create or replace function public.report_problem(p_order uuid, p_kind public.dispute_kind, p_note text default '')
returns public.disputes language plpgsql security definer set search_path = public as $$
declare
  v public.orders;
  d public.disputes;
begin
  select * into v from public.orders where id = p_order and customer_id = auth.uid() for update;
  if v.id is null then raise exception 'not_found'; end if;
  if v.status not in ('photos_ready', 'approved', 'auto_approved') then raise exception 'cannot_report'; end if;
  if v.status <> 'photos_ready' and coalesce(v.approved_at, v.finished_at)
       + make_interval(mins => public.setting_int('dispute_window_minutes')) < now() then
    raise exception 'dispute_window_closed';
  end if;
  insert into public.disputes (order_id, kind, note, outcome)
  values (p_order, p_kind, p_note, case when p_kind = 'damage' then 'damage_priority'::public.dispute_outcome
                                        else 'under_review'::public.dispute_outcome end)
  returning * into d;
  update public.orders set status = 'disputed' where id = p_order;
  update public.payouts set status = 'held', hold_reason = 'customer_dispute' where order_id = p_order;
  if p_kind = 'damage' then
    update public.washers set status = 'paused' where id = v.washer_id;
  end if;
  perform public.log_event(p_order, 'disputed', jsonb_build_object('kind', p_kind));
  return d;
end;
$$;

-- Account deletion (App Store requirement). Refused while a wash is in progress.
create or replace function public.delete_my_account() returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.orders where customer_id = auth.uid() and status in ('on_the_way', 'washing')) then
    return false;
  end if;
  update public.customers set deleted_at = now(), name = '', push_token = null where id = auth.uid();
  delete from public.vehicles where customer_id = auth.uid();
  return true;
end;
$$;

-- Society search for C09c.
create or replace function public.search_societies(p_query text)
returns setof public.societies language sql stable as $$
  select * from public.societies
  where p_query = '' or (name || ' ' || area) ilike '%' || p_query || '%'
  order by is_live desc, name limit 20;
$$;

-- Nearest live society for C09.
create or replace function public.nearest_society(p_lat double precision, p_lng double precision)
returns public.societies language sql stable as $$
  select * from public.societies
  where location is not null
  order by location <-> st_point(p_lng, p_lat)::geography
  limit 1;
$$;

-- Slots for one day with availability, used by C12.
create or replace function public.available_slots(p_society uuid, p_day date)
returns table (start_hour int, end_hour int, available boolean)
language sql stable as $$
  select t.start_hour, t.end_hour,
         (p_day + make_interval(hours => t.end_hour - 1)) > (now() at time zone 'Asia/Kolkata')
         and (select count(*) from public.washer_societies ws
                join public.washers w on w.id = ws.washer_id
               where ws.society_id = p_society and w.status in ('probation', 'active'))
             * 2 > (select count(*) from public.orders o
                     where o.society_id = p_society
                       and o.status not in ('cancelled', 'no_washer', 'pending_payment')
                       and o.slot_start = (p_day + make_interval(hours => t.start_hour)) at time zone 'Asia/Kolkata')
  from public.slot_templates t order by t.start_hour;
$$;

-- ---------------------------------------------------------------------------
-- Scheduled jobs (enable pg_cron in the dashboard, then uncomment):
-- select cron.schedule('auto-approve', '* * * * *', $$
--   update public.orders set status = 'auto_approved', approved_at = now()
--   where status = 'photos_ready' and auto_approve_at < now() $$);
-- Payouts before midnight and no-show refunds run as edge functions on a
-- schedule; see backend/supabase/functions.

-- Realtime for live order screens.
alter publication supabase_realtime add table public.orders;
