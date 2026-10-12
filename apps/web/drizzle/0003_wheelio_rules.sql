-- Neon/Better Auth identity is a text ID, set by the trusted backend inside
-- the same transaction as each operation. Never accept a user ID from a request.
create or replace function public.current_user_id() returns text
language sql stable as $$
  select nullif(current_setting('wheelio.user_id', true), '');
$$;
--> statement-breakpoint

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where id = public.current_user_id());
$$;
--> statement-breakpoint

create policy "catalogue readable" on public.vehicle_types for select using (true);
--> statement-breakpoint
create policy "societies readable" on public.societies for select using (true);
--> statement-breakpoint
create policy "slots readable" on public.slot_templates for select using (true);
--> statement-breakpoint
create policy "settings readable" on public.app_settings for select using (true);
--> statement-breakpoint
create policy "videos readable by washers" on public.training_videos for select using (public.current_user_id() is not null);
--> statement-breakpoint

create policy "customer reads self" on public.customers for select using (id = public.current_user_id() or public.is_admin());
--> statement-breakpoint
create policy "customer updates self" on public.customers for update using (id = public.current_user_id())
  with check (id = public.current_user_id());
--> statement-breakpoint

create policy "washer reads self" on public.washers for select using (id = public.current_user_id() or public.is_admin());
--> statement-breakpoint

create policy "customer vehicles" on public.vehicles for all using (customer_id = public.current_user_id())
  with check (customer_id = public.current_user_id());
--> statement-breakpoint
create policy "admin vehicles" on public.vehicles for select using (public.is_admin());
--> statement-breakpoint

create policy "customer orders" on public.orders for select using (customer_id = public.current_user_id());
--> statement-breakpoint
create policy "washer orders" on public.orders for select using (washer_id = public.current_user_id());
--> statement-breakpoint
create policy "admin orders" on public.orders for select using (public.is_admin());
--> statement-breakpoint

create policy "order events visible with order" on public.order_events for select using (
  exists (select 1 from public.orders o where o.id = order_id
          and (o.customer_id = public.current_user_id() or o.washer_id = public.current_user_id() or public.is_admin())));
--> statement-breakpoint

create policy "photos visible with order" on public.order_photos for select using (
  exists (select 1 from public.orders o where o.id = order_id
          and (o.customer_id = public.current_user_id() or o.washer_id = public.current_user_id() or public.is_admin())));
--> statement-breakpoint

-- Entry pass is shared with the assigned washer only.
create policy "entry pass for assigned washer" on public.entry_passes for select using (
  exists (select 1 from public.orders o where o.id = order_id
          and (o.washer_id = public.current_user_id() or o.customer_id = public.current_user_id() or public.is_admin())));
--> statement-breakpoint

create policy "customer payments" on public.payments for select using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = public.current_user_id() or public.is_admin())));
--> statement-breakpoint
create policy "customer refunds" on public.refunds for select using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = public.current_user_id() or public.is_admin())));
--> statement-breakpoint
create policy "washer payouts" on public.payouts for select using (washer_id = public.current_user_id() or public.is_admin());
--> statement-breakpoint
create policy "customer credits" on public.credits_ledger for select using (customer_id = public.current_user_id() or public.is_admin());
--> statement-breakpoint
create policy "ratings visible" on public.ratings for select using (
  washer_id = public.current_user_id() or public.is_admin() or
  exists (select 1 from public.orders o where o.id = order_id and o.customer_id = public.current_user_id()));
--> statement-breakpoint
create policy "customer disputes" on public.disputes for select using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = public.current_user_id() or public.is_admin())));
--> statement-breakpoint
create policy "washer offers" on public.job_offers for select using (washer_id = public.current_user_id() or public.is_admin());
--> statement-breakpoint
create policy "washer training" on public.washer_training for select using (washer_id = public.current_user_id() or public.is_admin());
--> statement-breakpoint
create policy "washer quiz" on public.quiz_attempts for select using (washer_id = public.current_user_id() or public.is_admin());
--> statement-breakpoint

-- ---------------------------------------------------------------------------
-- Helpers

create or replace function public.setting_int(k text) returns int
language sql stable as $$
  select nullif(value::text, 'null')::int from public.app_settings where key = k;
$$;
--> statement-breakpoint

create or replace function public.log_event(p_order uuid, p_kind text, p_data jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.order_events (order_id, kind, data, actor) values (p_order, p_kind, p_data, public.current_user_id());
$$;
--> statement-breakpoint


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
  select * into v_customer from public.customers where id = public.current_user_id() and deleted_at is null for update;
  if v_customer.id is null then raise exception 'not_logged_in'; end if;
  if not exists (select 1 from public.societies where id = p_society and is_live) then
    raise exception 'society_not_live';
  end if;
  if p_floor is null or btrim(p_floor) = '' then raise exception 'floor_required'; end if;
  if p_slot_start < now() - interval '30 minutes' then raise exception 'slot_in_past'; end if;
  if p_use_free_wash and v_customer.free_washes < 1 then raise exception 'no_free_washes'; end if;

  if p_slot_start is null or p_slot_end is null or p_slot_end <= p_slot_start then
    raise exception 'invalid_slot';
  end if;
  if (p_lat is null) <> (p_lng is null) or p_lat not between -90 and 90 or p_lng not between -180 and 180 then
    raise exception 'invalid_location';
  end if;

  select price_paise into v_price from public.vehicle_types where kind = p_kind and active;
  if v_price is null then raise exception 'unknown_vehicle_type'; end if;

  if p_use_free_wash then
    update public.customers set free_washes = free_washes - 1 where id = v_customer.id;
    v_price := 0;
  end if;

  insert into public.vehicles (customer_id, plate, kind, society_id, tower, floor, slot)
  values (public.current_user_id(), upper(p_plate), p_kind, p_society, p_tower, p_floor, p_slot)
  on conflict (customer_id, plate) do update
    set kind = excluded.kind, society_id = excluded.society_id, tower = excluded.tower,
        floor = excluded.floor, slot = excluded.slot
  returning id into v_vehicle;

  insert into public.orders (customer_id, vehicle_id, society_id, tower, floor, slot, location,
                             slot_start, slot_end, price_paise, used_free_wash, note_text, note_media_path)
  values (public.current_user_id(), v_vehicle, p_society, p_tower, p_floor, p_slot,
          case when p_lat is null then null else st_point(p_lng, p_lat)::geography end,
          p_slot_start, p_slot_end, v_price, p_use_free_wash, coalesce(p_note_text, ''), p_note_media_path)
  returning * into v_order;

  if p_use_free_wash then
    insert into public.credits_ledger (customer_id, delta, reason, order_id)
    values (v_customer.id, -1, 'booking_reserved', v_order.id);
  end if;
  perform public.log_event(v_order.id, 'created');
  return v_order;
end;
$$;
--> statement-breakpoint

create or replace function public.cancel_order(p_order uuid, p_reason text default null)
returns public.orders language plpgsql security definer set search_path = public as $$
declare
  v public.orders;
  v_fee int := 0;
begin
  select * into v from public.orders where id = p_order and customer_id = public.current_user_id() for update;
  if v.id is null then raise exception 'not_found'; end if;
  if v.status not in ('pending_payment', 'payment_pending', 'searching', 'on_the_way') then
    raise exception 'cannot_cancel_now';
  end if;
  if v.status = 'on_the_way' then v_fee := coalesce(public.setting_int('cancellation_fee_paise'), 0); end if;

  update public.orders set status = 'cancelled', cancelled_at = now(), cancel_reason = p_reason
  where id = p_order returning * into v;

  if exists (select 1 from public.payments where order_id = p_order and status in ('authorized', 'captured')) then
    insert into public.refunds (order_id, amount_paise, reason) values (p_order, greatest(v.price_paise - v_fee, 0), 'customer_cancelled');
  end if;
  if v.used_free_wash then
    update public.customers set free_washes = free_washes + 1 where id = v.customer_id;
    insert into public.credits_ledger (customer_id, delta, reason, order_id) values (v.customer_id, 1, 'cancel_return', p_order);
  end if;
  perform public.log_event(p_order, 'cancelled', jsonb_build_object('reason', p_reason, 'fee_paise', v_fee));
  return v;
end;
$$;
--> statement-breakpoint

create or replace function public.approve_order(p_order uuid)
returns public.orders language plpgsql security definer set search_path = public as $$
declare v public.orders;
begin
  update public.orders set status = 'approved', approved_at = now()
  where id = p_order and customer_id = public.current_user_id() and status = 'photos_ready'
  returning * into v;
  if v.id is null then raise exception 'cannot_approve'; end if;
  update public.payouts set status = 'released' where order_id = p_order and status = 'pending';
  perform public.log_event(p_order, 'approved');
  return v;
end;
$$;
--> statement-breakpoint

create or replace function public.rate_order(p_order uuid, p_stars int, p_tags text[] default '{}', p_comment text default '')
returns void language plpgsql security definer set search_path = public as $$
declare v public.orders;
begin
  select * into v from public.orders where id = p_order and customer_id = public.current_user_id()
    and status in ('approved', 'auto_approved', 'dispute_rejected');
  if v.id is null then raise exception 'cannot_rate'; end if;
  insert into public.ratings (order_id, washer_id, stars, tags, comment, needs_review)
  values (p_order, v.washer_id, p_stars, p_tags, p_comment, p_stars <= 2)
  on conflict (order_id) do update set stars = excluded.stars, tags = excluded.tags, comment = excluded.comment, needs_review = excluded.needs_review;
  update public.washers w set rating = (select avg(stars) from public.ratings r where r.washer_id = w.id)
  where w.id = v.washer_id;
end;
$$;
--> statement-breakpoint

create or replace function public.report_problem(p_order uuid, p_kind public.dispute_kind, p_note text default '')
returns public.disputes language plpgsql security definer set search_path = public as $$
declare
  v public.orders;
  d public.disputes;
begin
  select * into v from public.orders where id = p_order and customer_id = public.current_user_id() for update;
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
--> statement-breakpoint

-- Account deletion (App Store requirement). Refused while a wash is in progress.
create or replace function public.delete_my_account() returns boolean
language plpgsql security definer set search_path = public as $$
declare v_id text := public.current_user_id(); v_email text;
begin
  -- Lock the same customer row used when creating orders.
  perform 1 from public.customers where id = v_id and deleted_at is null for update;
  if not found then raise exception 'not_logged_in'; end if;
  if exists (select 1 from public.orders where customer_id = v_id
             and status in ('pending_payment', 'payment_pending', 'searching', 'on_the_way', 'washing', 'photos_ready', 'disputed')) then
    return false;
  end if;
  select email into v_email from public."user" where id = v_id;
  update public.customers set deleted_at = now(), name = '', phone = 'deleted:' || v_id,
    notifications_on = false, push_token = null where id = v_id;
  -- Referenced vehicles/order history must be retained; deleting them violates FKs.
  -- Scrub identifying vehicle details instead of removing financial history.
  update public.vehicles set plate = 'DELETED-' || id::text, tower = '', floor = null,
    slot = '', society_id = null where customer_id = v_id;
  update public.orders set tower = '', floor = '', slot = '', location = null,
    note_text = '', note_media_path = null where customer_id = v_id;
  delete from public.session where user_id = v_id;
  delete from public.account where user_id = v_id;
  delete from public.verification where identifier = v_email;
  update public."user" set name = '', email = 'deleted.' || v_id || '@accounts.invalid',
    image = null, email_verified = false, updated_at = now() where id = v_id;
  return true;
end;
$$;
--> statement-breakpoint

-- Society search for C09c.
create or replace function public.search_societies(p_query text)
returns setof public.societies language sql stable as $$
  select * from public.societies
  where p_query = '' or (name || ' ' || area) ilike '%' || p_query || '%'
  order by is_live desc, name limit 20;
$$;
--> statement-breakpoint

-- Nearest live society for C09.
create or replace function public.nearest_society(p_lat double precision, p_lng double precision)
returns public.societies language sql stable as $$
  select * from public.societies
  where location is not null and is_live
  order by location <-> st_point(p_lng, p_lat)::geography
  limit 1;
$$;
--> statement-breakpoint

-- Slots for one day with availability, used by C12.
create or replace function public.available_slots(p_society uuid, p_day date)
returns table (start_hour int, end_hour int, available boolean)
language sql stable security definer set search_path = public as $$
  select t.start_hour, t.end_hour,
         exists (select 1 from public.societies where id = p_society and is_live)
         and (p_day + make_interval(hours => t.end_hour - 1)) > (now() at time zone 'Asia/Kolkata')
         and (select count(*) from public.washer_societies ws
                join public.washers w on w.id = ws.washer_id
               where ws.society_id = p_society and w.status in ('probation', 'active'))
             * 2 > (select count(*) from public.orders o
                     where o.society_id = p_society
                       and o.status not in ('cancelled', 'no_washer', 'pending_payment')
                       and o.slot_start = (p_day + make_interval(hours => t.start_hour)) at time zone 'Asia/Kolkata')
  from public.slot_templates t order by t.start_hour;
$$;
--> statement-breakpoint


-- Initial configuration retains proposed values and undecided fees.
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
--> statement-breakpoint

insert into public.vehicle_types (kind, name, minutes, price_paise, sort) values
  ('bike', 'Bike or scooter', 15, 6900, 1),
  ('hatchback', 'Hatchback', 20, 14900, 2),
  ('sedan', 'Sedan or compact SUV', 20, 17900, 3),
  ('suv', 'SUV or MUV', 25, 21900, 4);
--> statement-breakpoint

insert into public.slot_templates (start_hour, end_hour) values (6, 8), (8, 10), (10, 12), (12, 14), (14, 16), (16, 18);
--> statement-breakpoint
revoke all on function public.current_user_id() from public;
--> statement-breakpoint
revoke all on function public.is_admin() from public;
--> statement-breakpoint
revoke all on function public.setting_int(text) from public;
--> statement-breakpoint
revoke all on function public.log_event(uuid, text, jsonb) from public;
--> statement-breakpoint
revoke all on function public.create_order(text, text, uuid, text, text, text, timestamptz, timestamptz, text, text, boolean, double precision, double precision) from public;
--> statement-breakpoint
revoke all on function public.cancel_order(uuid, text) from public;
--> statement-breakpoint
revoke all on function public.approve_order(uuid) from public;
--> statement-breakpoint
revoke all on function public.rate_order(uuid, int, text[], text) from public;
--> statement-breakpoint
revoke all on function public.report_problem(uuid, public.dispute_kind, text) from public;
--> statement-breakpoint
revoke all on function public.delete_my_account() from public;
--> statement-breakpoint
revoke all on function public.search_societies(text) from public;
--> statement-breakpoint
revoke all on function public.nearest_society(double precision, double precision) from public;
--> statement-breakpoint
revoke all on function public.available_slots(uuid, date) from public;
--> statement-breakpoint

create policy "admins read self" on public.admins for select using (id = public.current_user_id());
--> statement-breakpoint
create policy "washer society assignments" on public.washer_societies for select using (washer_id = public.current_user_id() or public.is_admin());
--> statement-breakpoint
