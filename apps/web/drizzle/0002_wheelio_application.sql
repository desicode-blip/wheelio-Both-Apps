CREATE TYPE "public"."dispute_kind" AS ENUM('not_clean', 'damage', 'wrong_vehicle', 'no_show');--> statement-breakpoint
CREATE TYPE "public"."dispute_outcome" AS ENUM('under_review', 'upheld', 'rejected', 'damage_priority');--> statement-breakpoint
CREATE TYPE "public"."order_status" AS ENUM('pending_payment', 'payment_pending', 'searching', 'on_the_way', 'washing', 'photos_ready', 'approved', 'auto_approved', 'disputed', 'dispute_upheld', 'dispute_rejected', 'cancelled', 'no_washer');--> statement-breakpoint
CREATE TYPE "public"."payment_status" AS ENUM('created', 'authorized', 'captured', 'failed', 'refunded', 'partially_refunded');--> statement-breakpoint
CREATE TYPE "public"."photo_role" AS ENUM('customer_id', 'before', 'after', 'dispute');--> statement-breakpoint
CREATE TYPE "public"."washer_status" AS ENUM('onboarding', 'under_review', 'probation', 'active', 'paused', 'removed');--> statement-breakpoint
CREATE SEQUENCE "public"."order_ref_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 20900 CACHE 1;--> statement-breakpoint
CREATE TABLE "admins" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL
);
--> statement-breakpoint
ALTER TABLE "admins" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "app_settings" (
	"key" text PRIMARY KEY NOT NULL,
	"value" jsonb NOT NULL,
	"note" text
);
--> statement-breakpoint
ALTER TABLE "app_settings" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "credits_ledger" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"customer_id" text NOT NULL,
	"delta" integer NOT NULL,
	"reason" text NOT NULL,
	"order_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "credits_ledger" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "customers" (
	"id" text PRIMARY KEY NOT NULL,
	"phone" text NOT NULL,
	"name" text DEFAULT '' NOT NULL,
	"free_washes" integer DEFAULT 0 NOT NULL,
	"notifications_on" boolean DEFAULT false NOT NULL,
	"push_token" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "customers_phone_unique" UNIQUE("phone"),
	CONSTRAINT "customers_free_washes_check" CHECK (free_washes >= 0)
);
--> statement-breakpoint
ALTER TABLE "customers" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "disputes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"ref" text DEFAULT ('WH-' || nextval('public.order_ref_seq')) NOT NULL,
	"order_id" uuid NOT NULL,
	"kind" "dispute_kind" NOT NULL,
	"note" text DEFAULT '' NOT NULL,
	"outcome" "dispute_outcome" DEFAULT 'under_review' NOT NULL,
	"decision_note" text DEFAULT '' NOT NULL,
	"credits_awarded" integer DEFAULT 0 NOT NULL,
	"ai_summary" jsonb,
	"decided_by" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"decided_at" timestamp with time zone,
	CONSTRAINT "disputes_ref_unique" UNIQUE("ref")
);
--> statement-breakpoint
ALTER TABLE "disputes" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "entry_passes" (
	"order_id" uuid PRIMARY KEY NOT NULL,
	"source" text DEFAULT 'whatsapp' NOT NULL,
	"storage_path" text,
	"text_value" text,
	"received_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "entry_passes" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "job_offers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"order_id" uuid NOT NULL,
	"washer_id" text NOT NULL,
	"offered_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"response" text,
	"responded_at" timestamp with time zone,
	CONSTRAINT "job_offers_order_id_washer_id_unique" UNIQUE("order_id","washer_id"),
	CONSTRAINT "job_offers_response_check" CHECK (response in ('accepted', 'declined', 'missed'))
);
--> statement-breakpoint
ALTER TABLE "job_offers" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "order_events" (
	"id" bigserial PRIMARY KEY NOT NULL,
	"order_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"data" jsonb DEFAULT '{}' NOT NULL,
	"actor" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "order_events" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "order_photos" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"order_id" uuid NOT NULL,
	"role" "photo_role" NOT NULL,
	"angle" text NOT NULL,
	"storage_path" text NOT NULL,
	"taken_at" timestamp with time zone NOT NULL,
	"taken_lat" double precision,
	"taken_lng" double precision,
	"uploaded_by" text NOT NULL,
	"ai_check" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "order_photos_angle_check" CHECK (angle in ('front', 'back', 'left', 'right', 'closeup', 'video', 'other'))
);
--> statement-breakpoint
ALTER TABLE "order_photos" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"ref" text DEFAULT ('WH-' || nextval('public.order_ref_seq')) NOT NULL,
	"customer_id" text NOT NULL,
	"vehicle_id" uuid NOT NULL,
	"society_id" uuid NOT NULL,
	"tower" text DEFAULT '' NOT NULL,
	"floor" text NOT NULL,
	"slot" text DEFAULT '' NOT NULL,
	"location" "geography",
	"slot_start" timestamp with time zone NOT NULL,
	"slot_end" timestamp with time zone NOT NULL,
	"price_paise" integer NOT NULL,
	"used_free_wash" boolean DEFAULT false NOT NULL,
	"note_text" text DEFAULT '' NOT NULL,
	"note_media_path" text,
	"status" "order_status" DEFAULT 'pending_payment' NOT NULL,
	"washer_id" text,
	"accepted_at" timestamp with time zone,
	"arrives_by" timestamp with time zone,
	"running_late_minutes" integer,
	"washer_cant_find" boolean DEFAULT false NOT NULL,
	"entry_pass_received_at" timestamp with time zone,
	"started_at" timestamp with time zone,
	"finished_at" timestamp with time zone,
	"auto_approve_at" timestamp with time zone,
	"approved_at" timestamp with time zone,
	"cancelled_at" timestamp with time zone,
	"cancel_reason" text,
	"late_penalty_paise" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "orders_ref_unique" UNIQUE("ref"),
	CONSTRAINT "orders_location_point_check" CHECK (location is null or (ST_SRID(location::geometry) = 4326 and GeometryType(location::geometry) = 'POINT')),
	CONSTRAINT "orders_check" CHECK (slot_end > slot_start)
);
--> statement-breakpoint
ALTER TABLE "orders" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "payments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"order_id" uuid NOT NULL,
	"provider" text DEFAULT 'razorpay' NOT NULL,
	"provider_order_id" text,
	"provider_payment_id" text,
	"method" text,
	"amount_paise" integer NOT NULL,
	"status" "payment_status" DEFAULT 'created' NOT NULL,
	"raw" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "payments_provider_order_id_unique" UNIQUE("provider_order_id"),
	CONSTRAINT "payments_provider_payment_id_unique" UNIQUE("provider_payment_id")
);
--> statement-breakpoint
ALTER TABLE "payments" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "payouts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"washer_id" text NOT NULL,
	"order_id" uuid NOT NULL,
	"gross_paise" integer NOT NULL,
	"penalty_paise" integer DEFAULT 0 NOT NULL,
	"net_paise" integer NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"provider_transfer_id" text,
	"hold_reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"paid_at" timestamp with time zone,
	CONSTRAINT "payouts_order_id_unique" UNIQUE("order_id"),
	CONSTRAINT "payouts_status_check" CHECK (status in ('pending', 'held', 'released', 'paid', 'reversed'))
);
--> statement-breakpoint
ALTER TABLE "payouts" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "quiz_attempts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"washer_id" text NOT NULL,
	"language" text NOT NULL,
	"score" integer NOT NULL,
	"passed" boolean NOT NULL,
	"transcript" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "quiz_attempts" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "ratings" (
	"order_id" uuid PRIMARY KEY NOT NULL,
	"washer_id" text NOT NULL,
	"stars" integer NOT NULL,
	"tags" text[] DEFAULT '{}' NOT NULL,
	"comment" text DEFAULT '' NOT NULL,
	"needs_review" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "ratings_stars_check" CHECK (stars between 1 and 5)
);
--> statement-breakpoint
ALTER TABLE "ratings" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "refunds" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"order_id" uuid NOT NULL,
	"payment_id" uuid,
	"amount_paise" integer NOT NULL,
	"reason" text NOT NULL,
	"provider_refund_id" text,
	"bank_ref" text,
	"status" text DEFAULT 'started' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"processed_at" timestamp with time zone,
	CONSTRAINT "refunds_status_check" CHECK (status in ('started', 'processed', 'failed'))
);
--> statement-breakpoint
ALTER TABLE "refunds" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "slot_templates" (
	"id" serial PRIMARY KEY NOT NULL,
	"start_hour" integer NOT NULL,
	"end_hour" integer NOT NULL,
	CONSTRAINT "slot_templates_start_hour_check" CHECK (start_hour between 0 and 23),
	CONSTRAINT "slot_templates_end_hour_check" CHECK (end_hour between 1 and 24 and end_hour > start_hour)
);
--> statement-breakpoint
ALTER TABLE "slot_templates" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "societies" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"area" text NOT NULL,
	"city" text DEFAULT 'Hyderabad' NOT NULL,
	"pincode" text,
	"location" "geography",
	"is_live" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "societies_location_point_check" CHECK (location is null or (ST_SRID(location::geometry) = 4326 and GeometryType(location::geometry) = 'POINT'))
);
--> statement-breakpoint
ALTER TABLE "societies" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "training_videos" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"youtube_id" text NOT NULL,
	"language" text NOT NULL,
	"vehicle_kind" text,
	"is_refresher" boolean DEFAULT false NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	CONSTRAINT "training_videos_language_check" CHECK (language in ('hi', 'te', 'en'))
);
--> statement-breakpoint
ALTER TABLE "training_videos" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "vehicle_types" (
	"kind" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"minutes" integer NOT NULL,
	"price_paise" integer NOT NULL,
	"sort" integer DEFAULT 0 NOT NULL,
	"active" boolean DEFAULT true NOT NULL,
	CONSTRAINT "vehicle_types_kind_check" CHECK (kind in ('bike', 'hatchback', 'sedan', 'suv')),
	CONSTRAINT "vehicle_types_price_paise_check" CHECK (price_paise > 0)
);
--> statement-breakpoint
ALTER TABLE "vehicle_types" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "vehicles" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"customer_id" text NOT NULL,
	"plate" text NOT NULL,
	"kind" text NOT NULL,
	"society_id" uuid,
	"tower" text DEFAULT '' NOT NULL,
	"floor" text,
	"slot" text DEFAULT '' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "vehicles_customer_id_plate_unique" UNIQUE("customer_id","plate")
);
--> statement-breakpoint
ALTER TABLE "vehicles" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "washer_societies" (
	"washer_id" text NOT NULL,
	"society_id" uuid NOT NULL,
	CONSTRAINT "washer_societies_washer_id_society_id_pk" PRIMARY KEY("washer_id","society_id")
);
--> statement-breakpoint
ALTER TABLE "washer_societies" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "washer_training" (
	"washer_id" text NOT NULL,
	"video_id" uuid NOT NULL,
	"watched_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "washer_training_washer_id_video_id_pk" PRIMARY KEY("washer_id","video_id")
);
--> statement-breakpoint
ALTER TABLE "washer_training" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
CREATE TABLE "washers" (
	"id" text PRIMARY KEY NOT NULL,
	"phone" text NOT NULL,
	"name" text DEFAULT '' NOT NULL,
	"language" text DEFAULT 'hi' NOT NULL,
	"status" "washer_status" DEFAULT 'onboarding' NOT NULL,
	"kyc_ref" text,
	"face_hash" text,
	"payout_ref" text,
	"probation_day" integer DEFAULT 0 NOT NULL,
	"daily_limit" integer DEFAULT 2 NOT NULL,
	"rating" numeric(3, 2) DEFAULT 0 NOT NULL,
	"washes" integer DEFAULT 0 NOT NULL,
	"refresher_due_at" timestamp with time zone,
	"online" boolean DEFAULT false NOT NULL,
	"last_location" "geography",
	"last_seen_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "washers_phone_unique" UNIQUE("phone"),
	CONSTRAINT "washers_last_location_point_check" CHECK (last_location is null or (ST_SRID(last_location::geometry) = 4326 and GeometryType(last_location::geometry) = 'POINT')),
	CONSTRAINT "washers_language_check" CHECK (language in ('hi', 'te', 'en'))
);
--> statement-breakpoint
ALTER TABLE "washers" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "admins" ADD CONSTRAINT "admins_id_user_id_fk" FOREIGN KEY ("id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "credits_ledger" ADD CONSTRAINT "credits_ledger_customer_id_customers_id_fk" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "credits_ledger" ADD CONSTRAINT "credits_ledger_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "customers" ADD CONSTRAINT "customers_id_user_id_fk" FOREIGN KEY ("id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "disputes" ADD CONSTRAINT "disputes_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "entry_passes" ADD CONSTRAINT "entry_passes_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "job_offers" ADD CONSTRAINT "job_offers_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "job_offers" ADD CONSTRAINT "job_offers_washer_id_washers_id_fk" FOREIGN KEY ("washer_id") REFERENCES "public"."washers"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_events" ADD CONSTRAINT "order_events_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_photos" ADD CONSTRAINT "order_photos_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_customer_id_customers_id_fk" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_vehicle_id_vehicles_id_fk" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_society_id_societies_id_fk" FOREIGN KEY ("society_id") REFERENCES "public"."societies"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_washer_id_washers_id_fk" FOREIGN KEY ("washer_id") REFERENCES "public"."washers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_washer_id_washers_id_fk" FOREIGN KEY ("washer_id") REFERENCES "public"."washers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payouts" ADD CONSTRAINT "payouts_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "quiz_attempts" ADD CONSTRAINT "quiz_attempts_washer_id_washers_id_fk" FOREIGN KEY ("washer_id") REFERENCES "public"."washers"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ratings" ADD CONSTRAINT "ratings_washer_id_washers_id_fk" FOREIGN KEY ("washer_id") REFERENCES "public"."washers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_customer_id_customers_id_fk" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_kind_vehicle_types_kind_fk" FOREIGN KEY ("kind") REFERENCES "public"."vehicle_types"("kind") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_society_id_societies_id_fk" FOREIGN KEY ("society_id") REFERENCES "public"."societies"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "washer_societies" ADD CONSTRAINT "washer_societies_washer_id_washers_id_fk" FOREIGN KEY ("washer_id") REFERENCES "public"."washers"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "washer_societies" ADD CONSTRAINT "washer_societies_society_id_societies_id_fk" FOREIGN KEY ("society_id") REFERENCES "public"."societies"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "washer_training" ADD CONSTRAINT "washer_training_washer_id_washers_id_fk" FOREIGN KEY ("washer_id") REFERENCES "public"."washers"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "washer_training" ADD CONSTRAINT "washer_training_video_id_training_videos_id_fk" FOREIGN KEY ("video_id") REFERENCES "public"."training_videos"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "washers" ADD CONSTRAINT "washers_id_user_id_fk" FOREIGN KEY ("id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "order_events_order_idx" ON "order_events" USING btree ("order_id","created_at");--> statement-breakpoint
CREATE INDEX "order_photos_order_idx" ON "order_photos" USING btree ("order_id","role");--> statement-breakpoint
CREATE INDEX "orders_customer_idx" ON "orders" USING btree ("customer_id","slot_start" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "orders_washer_idx" ON "orders" USING btree ("washer_id","slot_start");--> statement-breakpoint
CREATE INDEX "orders_open_idx" ON "orders" USING btree ("status") WHERE status in ('searching', 'on_the_way', 'washing', 'photos_ready');--> statement-breakpoint
CREATE INDEX "societies_location_idx" ON "societies" USING gist ("location");--> statement-breakpoint
CREATE INDEX "societies_name_idx" ON "societies" USING gin (to_tsvector('simple', name || ' ' || area));--> statement-breakpoint
CREATE INDEX "washers_location_idx" ON "washers" USING gist ("last_location");