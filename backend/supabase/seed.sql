-- Sample data for local development (supabase db reset runs this).
-- Same people and places as the designs and the app's mock backend.

insert into public.societies (id, name, area, city, pincode, location, is_live) values
  ('00000000-0000-0000-0000-000000000001', 'My Home Avatar', 'Narsingi', 'Hyderabad', '500089', st_point(78.358, 17.392)::geography, true),
  ('00000000-0000-0000-0000-000000000002', 'My Home Avali', 'Gachibowli', 'Hyderabad', '500032', st_point(78.349, 17.440)::geography, false),
  ('00000000-0000-0000-0000-000000000003', 'My Home Avishkaar', 'Kokapet', 'Hyderabad', '500075', st_point(78.334, 17.396)::geography, false)
on conflict (id) do nothing;

-- Training videos are chosen per language and vehicle type and embedded with
-- the official YouTube player (roadmap F23). Fill in real video IDs before the pilot.
-- insert into public.training_videos (youtube_id, language, vehicle_kind, sort) values ('<id>', 'hi', 'hatchback', 1);
