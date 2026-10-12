import { sql } from "drizzle-orm";
import { boolean, check, doublePrecision, customType, index, integer, jsonb, numeric, pgEnum, pgSequence, pgTable, primaryKey, serial, bigserial, text, timestamp, unique, uuid } from "drizzle-orm/pg-core";
import { user } from "./auth-schema";

// PostGIS geography; point/SRID constraints live alongside each location column.
const geography = customType<{ data: string }>({ dataType: () => "geography" });
export const orderRefSequence = pgSequence("order_ref_seq", { startWith: 20900 });

export const washerStatus = pgEnum("washer_status", ["onboarding", "under_review", "probation", "active", "paused", "removed"]);
export const orderStatus = pgEnum("order_status", ["pending_payment", "payment_pending", "searching", "on_the_way", "washing", "photos_ready", "approved", "auto_approved", "disputed", "dispute_upheld", "dispute_rejected", "cancelled", "no_washer"]);
export const photoRole = pgEnum("photo_role", ["customer_id", "before", "after", "dispute"]);
export const paymentStatus = pgEnum("payment_status", ["created", "authorized", "captured", "failed", "refunded", "partially_refunded"]);
export const disputeKind = pgEnum("dispute_kind", ["not_clean", "damage", "wrong_vehicle", "no_show"]);
export const disputeOutcome = pgEnum("dispute_outcome", ["under_review", "upheld", "rejected", "damage_priority"]);

export const appSettings = pgTable("app_settings", {
  key: text("key").primaryKey(),
  value: jsonb("value").notNull(),
  note: text("note"),
}, (table) => [
]).enableRLS();

export const vehicleTypes = pgTable("vehicle_types", {
  kind: text("kind").primaryKey(),
  name: text("name").notNull(),
  minutes: integer("minutes").notNull(),
  pricePaise: integer("price_paise").notNull(),
  sort: integer("sort").notNull().default(sql.raw("0")),
  active: boolean("active").notNull().default(sql.raw("true")),
}, (table) => [
  check("vehicle_types_kind_check", sql.raw("kind in ('bike', 'hatchback', 'sedan', 'suv')")),
  check("vehicle_types_price_paise_check", sql.raw("price_paise > 0")),
]).enableRLS();

export const societies = pgTable("societies", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  name: text("name").notNull(),
  area: text("area").notNull(),
  city: text("city").notNull().default(sql.raw("'Hyderabad'")),
  pincode: text("pincode"),
  location: geography("location"),
  isLive: boolean("is_live").notNull().default(sql.raw("false")),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
  check("societies_location_point_check", sql.raw("location is null or (ST_SRID(location::geometry) = 4326 and GeometryType(location::geometry) = 'POINT')")),
  index("societies_location_idx").using("gist", table.location),
  index("societies_name_idx").using("gin", sql.raw("to_tsvector('simple', name || ' ' || area)")),
]).enableRLS();

export const slotTemplates = pgTable("slot_templates", {
  id: serial("id").primaryKey(),
  startHour: integer("start_hour").notNull(),
  endHour: integer("end_hour").notNull(),
}, (table) => [
  check("slot_templates_start_hour_check", sql.raw("start_hour between 0 and 23")),
  check("slot_templates_end_hour_check", sql.raw("end_hour between 1 and 24 and end_hour > start_hour")),
]).enableRLS();

export const customers = pgTable("customers", {
  id: text("id").primaryKey().references(() => user.id, { onDelete: "cascade" }),
  phone: text("phone").notNull().unique(),
  name: text("name").notNull().default(sql.raw("''")),
  freeWashes: integer("free_washes").notNull().default(sql.raw("0")),
  notificationsOn: boolean("notifications_on").notNull().default(sql.raw("false")),
  pushToken: text("push_token"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
  deletedAt: timestamp("deleted_at", { withTimezone: true }),
}, (table) => [
  check("customers_free_washes_check", sql.raw("free_washes >= 0")),
]).enableRLS();

export const washers = pgTable("washers", {
  id: text("id").primaryKey().references(() => user.id, { onDelete: "cascade" }),
  phone: text("phone").notNull().unique(),
  name: text("name").notNull().default(sql.raw("''")),
  language: text("language").notNull().default(sql.raw("'hi'")),
  status: washerStatus("status").notNull().default(sql.raw("'onboarding'")),
  kycRef: text("kyc_ref"),
  faceHash: text("face_hash"),
  payoutRef: text("payout_ref"),
  probationDay: integer("probation_day").notNull().default(sql.raw("0")),
  dailyLimit: integer("daily_limit").notNull().default(sql.raw("2")),
  rating: numeric("rating", { precision: 3, scale: 2 }).notNull().default(sql.raw("0")),
  washes: integer("washes").notNull().default(sql.raw("0")),
  refresherDueAt: timestamp("refresher_due_at", { withTimezone: true }),
  online: boolean("online").notNull().default(sql.raw("false")),
  lastLocation: geography("last_location"),
  lastSeenAt: timestamp("last_seen_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
  check("washers_last_location_point_check", sql.raw("last_location is null or (ST_SRID(last_location::geometry) = 4326 and GeometryType(last_location::geometry) = 'POINT')")),
  check("washers_language_check", sql.raw("language in ('hi', 'te', 'en')")),
  index("washers_location_idx").using("gist", table.lastLocation),
]).enableRLS();

export const washerSocieties = pgTable("washer_societies", {
  washerId: text("washer_id").notNull().references(() => washers.id, { onDelete: "cascade" }),
  societyId: uuid("society_id").notNull().references(() => societies.id, { onDelete: "cascade" }),
}, (table) => [
  primaryKey({ columns: [table.washerId, table.societyId] }),
]).enableRLS();

export const admins = pgTable("admins", {
  id: text("id").primaryKey().references(() => user.id, { onDelete: "cascade" }),
  name: text("name").notNull(),
}, (table) => [
]).enableRLS();

export const vehicles = pgTable("vehicles", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  customerId: text("customer_id").notNull().references(() => customers.id, { onDelete: "cascade" }),
  plate: text("plate").notNull(),
  kind: text("kind").notNull().references(() => vehicleTypes.kind),
  societyId: uuid("society_id").references(() => societies.id),
  tower: text("tower").notNull().default(sql.raw("''")),
  floor: text("floor"),
  slot: text("slot").notNull().default(sql.raw("''")),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
  unique("vehicles_customer_id_plate_unique").on(table.customerId, table.plate),
]).enableRLS();

export const orders = pgTable("orders", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  ref: text("ref").notNull().unique().default(sql.raw("('WH-' || nextval('public.order_ref_seq'))")),
  customerId: text("customer_id").notNull().references(() => customers.id),
  vehicleId: uuid("vehicle_id").notNull().references(() => vehicles.id),
  societyId: uuid("society_id").notNull().references(() => societies.id),
  tower: text("tower").notNull().default(sql.raw("''")),
  floor: text("floor").notNull(),
  slot: text("slot").notNull().default(sql.raw("''")),
  location: geography("location"),
  slotStart: timestamp("slot_start", { withTimezone: true }).notNull(),
  slotEnd: timestamp("slot_end", { withTimezone: true }).notNull(),
  pricePaise: integer("price_paise").notNull(),
  usedFreeWash: boolean("used_free_wash").notNull().default(sql.raw("false")),
  noteText: text("note_text").notNull().default(sql.raw("''")),
  noteMediaPath: text("note_media_path"),
  status: orderStatus("status").notNull().default(sql.raw("'pending_payment'")),
  washerId: text("washer_id").references(() => washers.id),
  acceptedAt: timestamp("accepted_at", { withTimezone: true }),
  arrivesBy: timestamp("arrives_by", { withTimezone: true }),
  runningLateMinutes: integer("running_late_minutes"),
  washerCantFind: boolean("washer_cant_find").notNull().default(sql.raw("false")),
  entryPassReceivedAt: timestamp("entry_pass_received_at", { withTimezone: true }),
  startedAt: timestamp("started_at", { withTimezone: true }),
  finishedAt: timestamp("finished_at", { withTimezone: true }),
  autoApproveAt: timestamp("auto_approve_at", { withTimezone: true }),
  approvedAt: timestamp("approved_at", { withTimezone: true }),
  cancelledAt: timestamp("cancelled_at", { withTimezone: true }),
  cancelReason: text("cancel_reason"),
  latePenaltyPaise: integer("late_penalty_paise").notNull().default(sql.raw("0")),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
  check("orders_location_point_check", sql.raw("location is null or (ST_SRID(location::geometry) = 4326 and GeometryType(location::geometry) = 'POINT')")),
  check("orders_check", sql.raw("slot_end > slot_start")),
  index("orders_customer_idx").on(table.customerId, table.slotStart.desc()),
  index("orders_washer_idx").on(table.washerId, table.slotStart),
  index("orders_open_idx").on(table.status).where(sql.raw("status in ('searching', 'on_the_way', 'washing', 'photos_ready')")),
]).enableRLS();

export const orderEvents = pgTable("order_events", {
  id: bigserial("id", { mode: "number" }).primaryKey(),
  orderId: uuid("order_id").notNull().references(() => orders.id, { onDelete: "cascade" }),
  kind: text("kind").notNull(),
  data: jsonb("data").notNull().default(sql.raw("'{}'")),
  actor: text("actor"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
  index("order_events_order_idx").on(table.orderId, table.createdAt),
]).enableRLS();

export const orderPhotos = pgTable("order_photos", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  orderId: uuid("order_id").notNull().references(() => orders.id, { onDelete: "cascade" }),
  role: photoRole("role").notNull(),
  angle: text("angle").notNull(),
  storagePath: text("storage_path").notNull(),
  takenAt: timestamp("taken_at", { withTimezone: true }).notNull(),
  takenLat: doublePrecision("taken_lat"),
  takenLng: doublePrecision("taken_lng"),
  uploadedBy: text("uploaded_by").notNull(),
  aiCheck: jsonb("ai_check"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
  check("order_photos_angle_check", sql.raw("angle in ('front', 'back', 'left', 'right', 'closeup', 'video', 'other')")),
  index("order_photos_order_idx").on(table.orderId, table.role),
]).enableRLS();

export const entryPasses = pgTable("entry_passes", {
  orderId: uuid("order_id").primaryKey().references(() => orders.id, { onDelete: "cascade" }),
  source: text("source").notNull().default(sql.raw("'whatsapp'")),
  storagePath: text("storage_path"),
  textValue: text("text_value"),
  receivedAt: timestamp("received_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
]).enableRLS();

export const payments = pgTable("payments", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  orderId: uuid("order_id").notNull().references(() => orders.id),
  provider: text("provider").notNull().default(sql.raw("'razorpay'")),
  providerOrderId: text("provider_order_id").unique(),
  providerPaymentId: text("provider_payment_id").unique(),
  method: text("method"),
  amountPaise: integer("amount_paise").notNull(),
  status: paymentStatus("status").notNull().default(sql.raw("'created'")),
  raw: jsonb("raw"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
]).enableRLS();

export const refunds = pgTable("refunds", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  orderId: uuid("order_id").notNull().references(() => orders.id),
  paymentId: uuid("payment_id").references(() => payments.id),
  amountPaise: integer("amount_paise").notNull(),
  reason: text("reason").notNull(),
  providerRefundId: text("provider_refund_id"),
  bankRef: text("bank_ref"),
  status: text("status").notNull().default(sql.raw("'started'")),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
  processedAt: timestamp("processed_at", { withTimezone: true }),
}, (table) => [
  check("refunds_status_check", sql.raw("status in ('started', 'processed', 'failed')")),
]).enableRLS();

export const payouts = pgTable("payouts", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  washerId: text("washer_id").notNull().references(() => washers.id),
  orderId: uuid("order_id").notNull().unique().references(() => orders.id),
  grossPaise: integer("gross_paise").notNull(),
  penaltyPaise: integer("penalty_paise").notNull().default(sql.raw("0")),
  netPaise: integer("net_paise").notNull(),
  status: text("status").notNull().default(sql.raw("'pending'")),
  providerTransferId: text("provider_transfer_id"),
  holdReason: text("hold_reason"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
  paidAt: timestamp("paid_at", { withTimezone: true }),
}, (table) => [
  check("payouts_status_check", sql.raw("status in ('pending', 'held', 'released', 'paid', 'reversed')")),
]).enableRLS();

export const creditsLedger = pgTable("credits_ledger", {
  id: bigserial("id", { mode: "number" }).primaryKey(),
  customerId: text("customer_id").notNull().references(() => customers.id, { onDelete: "cascade" }),
  delta: integer("delta").notNull(),
  reason: text("reason").notNull(),
  orderId: uuid("order_id").references(() => orders.id),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
]).enableRLS();

export const ratings = pgTable("ratings", {
  orderId: uuid("order_id").primaryKey().references(() => orders.id, { onDelete: "cascade" }),
  washerId: text("washer_id").notNull().references(() => washers.id),
  stars: integer("stars").notNull(),
  tags: text("tags").array().notNull().default(sql.raw("'{}'")),
  comment: text("comment").notNull().default(sql.raw("''")),
  needsReview: boolean("needs_review").notNull().default(sql.raw("false")),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
  check("ratings_stars_check", sql.raw("stars between 1 and 5")),
]).enableRLS();

export const disputes = pgTable("disputes", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  ref: text("ref").notNull().unique().default(sql.raw("('WH-' || nextval('public.order_ref_seq'))")),
  orderId: uuid("order_id").notNull().references(() => orders.id),
  kind: disputeKind("kind").notNull(),
  note: text("note").notNull().default(sql.raw("''")),
  outcome: disputeOutcome("outcome").notNull().default(sql.raw("'under_review'")),
  decisionNote: text("decision_note").notNull().default(sql.raw("''")),
  creditsAwarded: integer("credits_awarded").notNull().default(sql.raw("0")),
  aiSummary: jsonb("ai_summary"),
  decidedBy: text("decided_by"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
  decidedAt: timestamp("decided_at", { withTimezone: true }),
}, (table) => [
]).enableRLS();

export const trainingVideos = pgTable("training_videos", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  youtubeId: text("youtube_id").notNull(),
  language: text("language").notNull(),
  vehicleKind: text("vehicle_kind"),
  isRefresher: boolean("is_refresher").notNull().default(sql.raw("false")),
  sort: integer("sort").notNull().default(sql.raw("0")),
}, (table) => [
  check("training_videos_language_check", sql.raw("language in ('hi', 'te', 'en')")),
]).enableRLS();

export const washerTraining = pgTable("washer_training", {
  washerId: text("washer_id").notNull().references(() => washers.id, { onDelete: "cascade" }),
  videoId: uuid("video_id").notNull().references(() => trainingVideos.id, { onDelete: "cascade" }),
  watchedAt: timestamp("watched_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
  primaryKey({ columns: [table.washerId, table.videoId] }),
]).enableRLS();

export const quizAttempts = pgTable("quiz_attempts", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  washerId: text("washer_id").notNull().references(() => washers.id, { onDelete: "cascade" }),
  language: text("language").notNull(),
  score: integer("score").notNull(),
  passed: boolean("passed").notNull(),
  transcript: jsonb("transcript"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
}, (table) => [
]).enableRLS();

export const jobOffers = pgTable("job_offers", {
  id: uuid("id").primaryKey().default(sql.raw("gen_random_uuid()")),
  orderId: uuid("order_id").notNull().references(() => orders.id, { onDelete: "cascade" }),
  washerId: text("washer_id").notNull().references(() => washers.id, { onDelete: "cascade" }),
  offeredAt: timestamp("offered_at", { withTimezone: true }).notNull().default(sql.raw("now()")),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  response: text("response"),
  respondedAt: timestamp("responded_at", { withTimezone: true }),
}, (table) => [
  check("job_offers_response_check", sql.raw("response in ('accepted', 'declined', 'missed')")),
  unique("job_offers_order_id_washer_id_unique").on(table.orderId, table.washerId),
]).enableRLS();
