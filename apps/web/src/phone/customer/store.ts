// App state plus an in-memory backend with the sample people and places from the designs
// (Ananya, Raju, My Home Avatar Tower 3, TS 09 EA 4521). Ported from AppStore.swift and
// Notifications.swift. Demo login: any valid mobile number, code 123456. Code 000000 = expired.

import { Brand } from "../ds/tokens";
import type { IconName } from "../ds/icons";
import type { Tone } from "../ds/tokens";
import { addDays, Fmt, isToday, newId, sleep, startOfDay } from "../lib/fmt";
import { appIsActive, buzz, ding, requestPermission, systemNotify, systemPermission, type Permission } from "../lib/device";
import { Hub, reactive, run, type Job } from "../lib/reactive";
import { Nav } from "../lib/nav";
import {
  awaitingUPI, BusinessRules, emptyNote, PhotoAngles, PlaceFmt, Slot, Status, VehicleTypes, type Captain, type Customer, type DisputeOutcome,
  type EntryNote, type Order, type OrderStatus, type PaymentMethod, type PaymentOutcome, type PhotoAngle, type Place, type ProblemKind,
  type Refund, type Society, type TimeSlot, type UploadState, type Vehicle, type VehicleType, type WashKind,
} from "./model";

// MARK: Routes

export type OtpStart = "entering" | "wrong" | "expired";
export type PayView = "processing" | "failed" | "pending";
export type HelpTopic = "notClean" | "late" | "booking" | "payment" | "other";

/** One route per screen ID (design read-me). */
export type Route =
  | { n: "welcome" } | { n: "vehicleType"; large?: boolean } | { n: "washType" } | { n: "vehicleNumber" } | { n: "photos" }
  | { n: "camera"; angle: PhotoAngle; denied?: boolean } | { n: "location"; off?: boolean } | { n: "addressSearch" } | { n: "floorSlot" }
  | { n: "entryNotes" } | { n: "timeSlot" } | { n: "review" } | { n: "login"; error?: boolean } | { n: "otp"; start: OtpStart } | { n: "name" }
  | { n: "paying"; view: PayView } | { n: "booked" } | { n: "whatsApp" } | { n: "notifyAsk" } | { n: "live" } | { n: "photoCompare" }
  | { n: "rate" } | { n: "reportProblem" } | { n: "problemPhotos"; kind: ProblemKind } | { n: "disputeStatus" } | { n: "refund" }
  | { n: "bookingDetail"; id: string } | { n: "repeatBooking"; id: string } | { n: "help" } | { n: "helpCaptain"; topic: HelpTopic }
  | { n: "helpEmergency" } | { n: "changePhone" } | { n: "notifications" } | { n: "refundUPI"; id: string | null }
  | { n: "notificationSettings" } | { n: "offline" } | { n: "serverError" } | { n: "sessionExpired" } | { n: "gallery" };

export class Router extends Nav<Route> {
  showSplash = true;
  /** Pay sheet (C17) shown over Review. */
  showPaySheet = false;

  /** After login: back to Check and pay with the pay sheet open, or home. */
  finishLogin() {
    const i = this.indexOf("review");
    if (i >= 0) {
      this.keep(i + 1);
      setTimeout(() => { this.showPaySheet = true; }, 450);
    } else {
      this.path = [];
      this.tab = 0;
    }
  }
}

// MARK: Notifications model

export type NotificationCategory = "bookings" | "payments" | "offers" | "account";
export const NotificationCategories: NotificationCategory[] = ["bookings", "payments", "offers", "account"];
export const Cat = {
  title: (c: NotificationCategory) => ({ bookings: "Booking updates", payments: "Payments and refunds", offers: "Offers and tips", account: "Account and security" })[c],
  detail: (c: NotificationCategory) => ({ bookings: "Captain accepted, on the way, photos ready", payments: "Refunds and payment problems", offers: "Free washes and discounts", account: "Sign-ins and number changes. Always on." })[c],
  filter: (c: NotificationCategory) => ({ bookings: "Bookings", payments: "Payments", offers: "Offers", account: "Account" })[c],
};

export type NotificationKind =
  | "bookingConfirmed" | "gatePassNeeded" | "captainAssigned" | "captainRunningLate" | "captainCantFind" | "washStarted" | "photosReady"
  | "approveReminder" | "autoApproved" | "noCaptain" | "bookingCancelled" | "washStatusCheck" | "noShowRefund" | "disputeDecision"
  | "refundCredited" | "paymentPending" | "freeWash" | "offer" | "phoneChanged" | "welcome";

export const Kind = {
  category: (k: NotificationKind): NotificationCategory =>
    k === "refundCredited" || k === "paymentPending" ? "payments" : k === "freeWash" || k === "offer" ? "offers" : k === "phoneChanged" || k === "welcome" ? "account" : "bookings",
  icon: (k: NotificationKind): IconName => ({
    bookingConfirmed: "check", gatePassNeeded: "door", captainAssigned: "location", captainRunningLate: "clock", captainCantFind: "warning",
    washStarted: "drop", photosReady: "camera", approveReminder: "clock", autoApproved: "sparkle", noCaptain: "close", bookingCancelled: "close",
    washStatusCheck: "search", noShowRefund: "rupee", disputeDecision: "flag", refundCredited: "rupee", paymentPending: "warning",
    freeWash: "gift", offer: "megaphone", phoneChanged: "lock", welcome: "bell",
  } as const)[k],
  tone: (k: NotificationKind): Tone => {
    if (["captainCantFind", "paymentPending", "phoneChanged"].includes(k)) return "error";
    if (["captainRunningLate", "approveReminder", "gatePassNeeded", "washStatusCheck"].includes(k)) return "wait";
    if (["noShowRefund", "photosReady", "autoApproved", "refundCredited", "freeWash", "bookingConfirmed"].includes(k)) return "ok";
    return "info";
  },
  /** Order states this notification still makes sense in. */
  liveStatuses: (k: NotificationKind): OrderStatus[] | null => {
    switch (k) {
      case "bookingConfirmed": return ["searching"];
      case "captainAssigned": case "captainRunningLate": case "captainCantFind": case "washStatusCheck": return ["onTheWay"];
      case "washStarted": return ["washing"];
      case "photosReady": case "approveReminder": return ["photosReady"];
      default: return null;
    }
  },
};

export type AppNotification = { id: string; kind: NotificationKind; title: string; body: string; date: Date; orderId: string | null; expiresAt: Date | null; read: boolean };
export type AlertStyle = "soundAndBanner" | "bannerOnly";
export const alertStyleTitle = (s: AlertStyle) => (s === "soundAndBanner" ? "Sound and banner" : "Banner only, no sound");

export type NotificationPrefs = { style: AlertStyle; mutedUntil: Date | null; categories: NotificationCategory[]; quietHours: boolean };
export const isMuted = (p: { mutedUntil: Date | null }) => !!p.mutedUntil && p.mutedUntil.getTime() > Date.now();
export const inQuietHours = () => { const h = new Date().getHours(); return h >= 22 || h < 7; };

// MARK: Store

/** Switches that force edge cases so every designed state can be reached without a backend. */
export type DemoScenario = {
  payment: PaymentOutcome; noCaptainFound: boolean; captainRunsLate: boolean; captainNoShow: boolean; captainCantFind: boolean;
  entryPassNeverArrives: boolean; noCaptainsToday: boolean; failBackPhotoOnce: boolean; disputeRejected: boolean; offline: boolean;
  emptyHistory: boolean; stepSeconds: number;
};
const newDemo = (): DemoScenario => ({
  payment: "success", noCaptainFound: false, captainRunsLate: false, captainNoShow: false, captainCantFind: false, entryPassNeverArrives: false,
  noCaptainsToday: false, failBackPhotoOnce: false, disputeRejected: false, offline: false, emptyHistory: false, stepSeconds: 5,
});

/** The booking being built, one small decision per screen. */
export type BookingDraft = {
  type: VehicleType | null; wash: WashKind | null; plate: string; photos: Partial<Record<PhotoAngle, UploadState>>; videoSeconds: number | null;
  place: Place | null; note: EntryNote; slot: TimeSlot | null; useFreeWash: boolean; isRepeat: boolean;
};
const newDraft = (p: Partial<BookingDraft> = {}): BookingDraft => ({
  type: null, wash: null, plate: "", photos: {}, videoSeconds: null, place: null, note: emptyNote(), slot: null, useFreeWash: false, isRepeat: false, ...p,
});
export const Draft = {
  photosDone: (d: BookingDraft) => Object.values(d.photos).filter((s) => s === "done").length,
  photosComplete: (d: BookingDraft) => PhotoAngles.every((a) => d.photos[a] === "done"),
  hasFailedPhoto: (d: BookingDraft) => Object.values(d.photos).includes("failed"),
  price: (d: BookingDraft) => (d.useFreeWash ? 0 : d.type?.price ?? 0),
};

export const societies: Society[] = [
  { id: "soc_avatar", name: "My Home Avatar", area: "Narsingi", city: "Hyderabad", pincode: "500089" },
  { id: "soc_avali", name: "My Home Avali", area: "Gachibowli", city: "Hyderabad", pincode: "500032" },
  { id: "soc_avishkaar", name: "My Home Avishkaar", area: "Kokapet", city: "Hyderabad", pincode: "500075" },
];
export const raju: Captain = { id: "wsh_raju", name: "Raju", rating: 4.8, washes: 212, initials: "RY" };
export const homePlace = (): Place => ({ society: societies[0], tower: "Tower 3", floor: "B2", slot: "41" });
export const sampleCar = (): Vehicle => ({ id: "veh_car", plate: "TS 09 EA 4521", type: VehicleTypes[1], place: homePlace() });
export const sampleScooter = (): Vehicle => ({ id: "veh_scooter", plate: "TS 09 HB 0731", type: VehicleTypes[0], place: { society: societies[0], tower: "Tower 3", floor: "B1", slot: "" } });
export const gpay: PaymentMethod = { id: "gpay", title: "Google Pay", detail: "ananya@okhdfc" };

export const DEMO_OTP = "123456";
export const EXPIRED_OTP = "000000";
export const SAMPLE_PHONE = "9848011223";

export type OtpResult = { kind: "ok"; isNew: boolean } | { kind: "wrong"; triesLeft: number } | { kind: "expired" } | { kind: "tooManyTries" };

export class AppStore {
  demo = newDemo();
  customer: Customer | null = null;
  vehicles: Vehicle[] = [];
  orders: Order[] = [];

  notifications: AppNotification[] = [];
  notificationPrefs: NotificationPrefs = { style: "soundAndBanner", mutedUntil: null, categories: [...NotificationCategories], quietHours: false };
  systemPermission: Permission = "unknown";
  /** Banner currently shown at the top of the app. */
  liveBanner: AppNotification | null = null;
  /** Short note shown at the bottom (e.g. "Things have moved on"). */
  toast: string | null = null;
  /** Order whose live screen is open (no banner needed for it). */
  viewingOrderId: string | null = null;
  draft = newDraft();
  currentOrderId: string | null = null;
  pendingPhone = "";
  /** "I've booked before" (phone + code only) or "I'm new here" (phone + code + name). */
  returningCustomer = false;
  payMethodId = "gpay";
  hasSeenWelcome = false;
  profilePhoto: string | null = null;
  pendingNewPhone = "";

  private otpTries = 0;
  private refCounter = 20914;
  private backPhotoFailed = false;
  private tasks: Record<string, Job> = {};

  constructor() { this.seedPastOrders(); }

  get isLoggedIn() { return this.customer != null; }
  get currentOrder() { return this.orders.find((o) => o.id === this.currentOrderId) ?? null; }
  get activeOrder() { return this.orders.find((o) => Status.isActive(o.status)) ?? null; }
  get upcomingOrders() {
    return this.demo.emptyHistory ? [] : this.orders.filter((o) => Status.isUpcoming(o.status)).sort((a, b) => Slot.start(a.slot).getTime() - Slot.start(b.slot).getTime());
  }
  get pastOrders() {
    return this.demo.emptyHistory ? [] : this.orders.filter((o) => !Status.isUpcoming(o.status) && o.status !== "pendingPayment").sort((a, b) => Slot.start(b.slot).getTime() - Slot.start(a.slot).getTime());
  }
  get myVehicles() { return this.demo.emptyHistory ? [] : this.vehicles; }
  order(id: string) { return this.orders.find((o) => o.id === id) ?? null; }

  private update(id: string, change: (o: Order) => void) {
    const o = this.order(id);
    if (!o) return;
    const old = { status: o.status, late: o.runningLateMinutes, checking: o.noShowChecking, cantFind: o.captainCantFind, credited: o.refund?.credited ?? false };
    change(o);
    this.notifyChanges(old, o);
  }

  private nextRef() { return `WH-${this.refCounter++}`; }

  private async latency(ms = 450) {
    await sleep(ms);
    if (this.demo.offline) throw new Error("offline");
  }

  private seedPastOrders() {
    const today = startOfDay(new Date());
    const past = (id: string, daysAgo: number, v: Vehicle, status: OrderStatus, o: { refund?: Refund; rating?: number; place?: Place; wash?: WashKind } = {}): Order => {
      const day = addDays(today, -daysAgo);
      return {
        id, ref: `WH-${20871 - daysAgo}`, vehicle: v, place: o.place ?? v.place ?? homePlace(), slot: { date: day, startHour: 8, endHour: 10, available: true },
        price: v.type.price, status, createdAt: day, note: emptyNote(), captain: status === "cancelled" ? null : raju, arrivesBy: null, runningLateMinutes: null,
        startedAt: new Date(day.getTime() + (8 * 60 + 32) * 60000), finishedAt: new Date(day.getTime() + (8 * 60 + 54) * 60000), autoApproveAt: null,
        entryPassReceived: true, captainCantFind: false, rating: o.rating ?? null, paidWith: gpay, refund: o.refund ?? null, dispute: null,
        usedFreeWash: false, customerSkippedPhotos: false, noShowChecking: false, wash: o.wash ?? "wetOutside",
      };
    };
    const d2 = addDays(today, -10);
    this.orders = [
      past("ord_past1", 7, sampleCar(), "approved", { rating: 4 }),
      past("ord_past2", 10, sampleCar(), "noCaptain", { refund: { amount: 149, startedAt: d2, method: "Google Pay · ananya@okhdfc", bankRef: "RZP8812001", credited: true, needsUPI: false, upi: null } }),
      past("ord_past3", 13, sampleScooter(), "cancelled"),
      // Same car, booked at another society (parents' place): its own entry, place highlighted.
      past("ord_past4", 16, sampleCar(), "approved", { rating: 5, place: { society: societies[1], tower: "Tower 1", floor: "B1", slot: "12" } }),
      // Same car and place, but a dry wash: its own entry, wash highlighted.
      past("ord_past5", 21, sampleCar(), "approved", { rating: 4, wash: "dryDusting" }),
    ];
  }

  // MARK: Auth (BACKEND: auth.signInWithOtp / verifyOtp)

  async requestOtp(phone: string) {
    await this.latency(700);
    this.pendingPhone = phone;
    this.otpTries = 0;
  }

  async verifyOtp(code: string): Promise<OtpResult> {
    await this.latency(600);
    if (code === EXPIRED_OTP) return { kind: "expired" };
    if (code !== DEMO_OTP) {
      this.otpTries += 1;
      const left = 3 - this.otpTries;
      return left <= 0 ? { kind: "tooManyTries" } : { kind: "wrong", triesLeft: left };
    }
    // Demo: anyone who says they've booked before is found as the sample customer.
    const known = this.pendingPhone === SAMPLE_PHONE || this.returningCustomer;
    this.customer = { id: `cus_${this.pendingPhone}`, phone: this.pendingPhone, name: known ? "Ananya Rao" : "", freeWashes: 0, notificationsOn: known, refundUPI: null };
    if (known && !this.vehicles.length) this.vehicles = [sampleCar(), sampleScooter()];
    if (known) this.seedSampleNotifications();
    else {
      this.notifications = [];
      this.notify("welcome", `Welcome to ${Brand.name}`, "Book a wash, see the photos, then pay. That’s it.", { deliver: false });
    }
    return { kind: "ok", isNew: !known };
  }

  /** Gallery shortcut: log in as the sample customer. */
  signInAsSample(freeWashes = 0) {
    this.customer = { id: "cus_ananya", phone: SAMPLE_PHONE, name: "Ananya Rao", freeWashes, notificationsOn: true, refundUPI: null };
    if (!this.vehicles.length) this.vehicles = [sampleCar(), sampleScooter()];
    if (!this.notifications.length) this.seedSampleNotifications();
  }

  signOut() {
    this.customer = null;
    this.vehicles = [];
    this.notifications = [];
    this.liveBanner = null;
  }

  async updateName(name: string) {
    await this.latency();
    if (this.customer) this.customer.name = name.trim();
  }

  async requestPhoneChange(phone: string) { await this.latency(700); this.pendingNewPhone = phone; }

  async confirmPhoneChange(code: string) {
    await this.latency(600);
    if (code !== DEMO_OTP) return false;
    if (this.customer) this.customer.phone = this.pendingNewPhone;
    this.pendingNewPhone = "";
    return true;
  }

  /** The captain from the running wash, else from the most recent wash. */
  get latestCaptainOrder() {
    const a = this.activeOrder;
    if (a && a.captain) return a;
    return this.pastOrders.find((o) => o.captain) ?? null;
  }

  /** Returns false while a wash is in progress. */
  async deleteAccount() {
    await this.latency();
    if (this.orders.some((o) => o.status === "washing")) return false;
    this.customer = null;
    this.vehicles = [];
    this.orders = [];
    this.notifications = [];
    this.notificationPrefs = { style: "soundAndBanner", mutedUntil: null, categories: [...NotificationCategories], quietHours: false };
    return true;
  }

  // MARK: Catalogue

  searchSocieties(q: string) {
    const s = q.trim().toLowerCase();
    if (!s) return societies;
    return societies.filter((x) => `${x.name} ${x.area}`.toLowerCase().includes(s));
  }

  timeSlots(day: Date): TimeSlot[] {
    const today = isToday(day);
    const hour = new Date().getHours();
    return [[6, 8], [8, 10], [10, 12], [12, 14], [14, 16], [16, 18]].map(([s, e]) => {
      // Demo: early windows today look full so the crossed-out state shows.
      const full = today && (this.demo.noCaptainsToday || s === 6 || (hour >= e - 1 && hour < 20));
      return { date: startOfDay(day), startHour: s, endHour: e, available: !full };
    });
  }

  get paymentMethods(): PaymentMethod[] {
    const upi = this.customer?.phone === SAMPLE_PHONE ? "UPI · ananya@okhdfc" : "UPI";
    return [
      { id: "gpay", title: "Google Pay", detail: upi },
      { id: "phonepe", title: "PhonePe", detail: "UPI" },
      { id: "upi_id", title: "Other UPI app", detail: "Enter UPI ID" },
      { id: "card", title: "Card", detail: "Debit or credit" },
    ];
  }

  // MARK: Booking

  /** BACKEND: storage upload. Fails the back photo once when the demo switch is on. */
  async uploadPhoto(a: PhotoAngle) {
    this.draft.photos[a] = "uploading";
    await sleep(700);
    if (this.demo.failBackPhotoOnce && a === "back" && !this.backPhotoFailed) {
      this.backPhotoFailed = true;
      this.draft.photos[a] = "failed";
    } else {
      this.draft.photos[a] = "done";
    }
  }

  startRepeat(v: Vehicle, place?: Place | null, wash?: WashKind | null) {
    this.draft = newDraft({ type: v.type, wash: wash ?? null, plate: v.plate, place: place ?? v.place, isRepeat: true });
  }

  startNewBooking() { this.draft = newDraft(); }

  /** BACKEND: rpc create_order, then Razorpay checkout. */
  async createOrderAndPay(): Promise<PaymentOutcome> {
    const d = this.draft;
    if (!d.type || !d.place || !d.slot) throw new Error("server");
    await this.latency(2200);
    let vehicle = this.vehicles.find((v) => v.plate === d.plate);
    if (!vehicle) {
      vehicle = { id: newId("veh"), plate: d.plate, type: d.type, place: d.place };
      this.vehicles.push(vehicle);
    }
    const method = this.paymentMethods.find((m) => m.id === this.payMethodId) ?? gpay;
    const order: Order = {
      id: newId("ord"), ref: this.nextRef(), vehicle, place: d.place, slot: d.slot, price: Draft.price(d), status: "pendingPayment", createdAt: new Date(),
      note: d.note, captain: null, arrivesBy: null, runningLateMinutes: null, startedAt: null, finishedAt: null, autoApproveAt: null,
      entryPassReceived: false, captainCantFind: false, rating: null, paidWith: method, refund: null, dispute: null, usedFreeWash: d.useFreeWash,
      customerSkippedPhotos: !Draft.photosComplete(d), noShowChecking: false, wash: d.wash,
    };
    this.orders.push(order);
    this.currentOrderId = order.id;
    switch (this.demo.payment) {
      case "failed":
        this.orders = this.orders.filter((o) => o.id !== order.id);
        return "failed";
      case "pending":
        this.update(order.id, (o) => { o.status = "paymentPending"; });
        return "pending";
      default:
        if (d.useFreeWash && this.customer) this.customer.freeWashes -= 1;
        this.startLifecycle(order.id);
        return "success";
    }
  }

  async checkPendingPayment(): Promise<PaymentOutcome> {
    await this.latency(1200);
    this.demo.payment = "success";
    if (this.currentOrderId) this.startLifecycle(this.currentOrderId);
    return "success";
  }

  private async sleepSteps(job: Job, n: number) {
    await sleep(this.demo.stepSeconds * n * 1000);
    return !job.cancelled;
  }

  private startLifecycle(id: string) {
    this.update(id, (o) => { o.status = "searching"; });
    this.tasks[id]?.cancel();
    this.tasks[id] = run(async (job) => {
      if (!(await this.sleepSteps(job, 1))) return;
      if (this.demo.noCaptainFound) {
        this.update(id, (o) => { o.status = "noCaptain"; o.refund = this.autoRefund(o); });
        return;
      }
      this.update(id, (o) => {
        o.status = "onTheWay";
        o.captain = raju;
        o.arrivesBy = new Date(Math.max(Date.now() + 25 * 60000, Slot.start(o.slot).getTime() + 40 * 60000));
      });
      if (!(await this.sleepSteps(job, 1))) return;
      if (!this.demo.entryPassNeverArrives) this.update(id, (o) => { o.entryPassReceived = true; });
      if (this.demo.captainNoShow) {
        // 1. Running late  2. Slot window passed, checking  3. 11:59 PM: full refund, captain penalised.
        this.update(id, (o) => { o.runningLateMinutes = 15; });
        if (!(await this.sleepSteps(job, 2))) return;
        this.update(id, (o) => { o.noShowChecking = true; });
        if (!(await this.sleepSteps(job, 2))) return;
        this.update(id, (o) => { o.status = "captainNoShow"; o.refund = this.autoRefund(o); });
        return;
      }
      if (this.demo.captainRunsLate) this.update(id, (o) => { o.runningLateMinutes = 15; });
      if (!(await this.sleepSteps(job, 1))) return;
      if (this.demo.captainCantFind) {
        // Waits for the customer's answer; see answerCantFind.
        this.update(id, (o) => { o.captainCantFind = true; });
        return;
      }
      await this.runWash(job, id);
    });
  }

  private async runWash(job: Job, id: string) {
    this.update(id, (o) => { o.status = "washing"; o.startedAt = new Date(); });
    if (!(await this.sleepSteps(job, 2))) return;
    const done = new Date();
    this.update(id, (o) => { o.status = "photosReady"; o.finishedAt = done; o.autoApproveAt = BusinessRules.autoApproveTime(done); });
  }

  answerCantFind(answer: string) {
    const id = this.currentOrderId;
    if (!id) return;
    if (answer === "not_here") { this.cancel(id).catch(() => {}); return; }
    this.update(id, (o) => { o.captainCantFind = false; });
    this.tasks[id] = run(async (job) => {
      if (!(await this.sleepSteps(job, 1))) return;
      await this.runWash(job, id);
    });
  }

  /** Refund for an automatic cancellation. Goes to the customer's UPI ID; if we don't have one yet, we ask for it. */
  autoRefund(o: Order): Refund {
    const upi = this.customer?.refundUPI ?? null;
    return { amount: o.price, startedAt: new Date(), method: upi ? `UPI · ${upi}` : "Waiting for your UPI ID", bankRef: `RZP${8812000 + Math.floor(Math.random() * 99999)}`, credited: false, needsUPI: true, upi };
  }

  /** Saves the refund UPI ID to the profile and sends any refunds that were waiting for it. */
  saveRefundUPI(raw: string) {
    const upi = raw.trim().toLowerCase();
    if (this.customer) this.customer.refundUPI = upi;
    for (const o of this.orders) {
      if (awaitingUPI(o.refund) && o.refund) {
        o.refund.upi = upi;
        o.refund.method = `UPI · ${upi}`;
        o.refund.startedAt = new Date();
      }
    }
  }

  private refundFor(o: Order, amount?: number): Refund {
    return {
      amount: amount ?? o.price, startedAt: new Date(),
      method: o.paidWith ? `${o.paidWith.title} · ${o.paidWith.detail.replace("UPI · ", "")}` : "UPI",
      bankRef: `RZP${8812000 + Math.floor(Math.random() * 99999)}`, credited: false, needsUPI: false, upi: null,
    };
  }

  /** BACKEND: rpc cancel_order. After a captain accepts, [CANCELLATION FEE] applies (not decided, so 0). */
  async cancel(id: string) {
    await this.latency(800);
    this.tasks[id]?.cancel();
    this.update(id, (o) => {
      const fee = o.status === "onTheWay" ? BusinessRules.cancellationFee ?? 0 : 0;
      o.refund = this.refundFor(o, o.price - fee);
      o.status = "cancelled";
      o.captainCantFind = false;
    });
  }

  /** BACKEND: rpc approve_order (releases the held money to the captain). */
  async approve(id: string) {
    await this.latency(600);
    this.tasks[id]?.cancel();
    this.update(id, (o) => { o.status = "approved"; });
  }

  async rate(id: string, stars: number) {
    await this.latency(400);
    this.update(id, (o) => { o.rating = stars; });
  }

  /** BACKEND: rpc report_problem. */
  async reportProblem(id: string, kind: ProblemKind, note: string) {
    await this.latency(900);
    this.tasks[id]?.cancel();
    const dispute = { ref: this.nextRef(), kind, createdAt: new Date(), note, outcome: (kind === "damage" ? "damagePriority" : "underReview") as DisputeOutcome, decisionNote: "", creditsAwarded: 0 };
    this.update(id, (o) => { o.status = "disputed"; o.dispute = dispute; });
    if (kind === "damage") return;
    this.tasks[id] = run(async (job) => {
      if (!(await this.sleepSteps(job, 2))) return;
      if (this.demo.disputeRejected) {
        this.update(id, (o) => {
          o.status = "disputeRejected";
          if (o.dispute) { o.dispute.outcome = "rejected"; o.dispute.decisionNote = "The scratch near the left door is visible in the 8:33 AM before-photo."; }
        });
      } else {
        if (this.customer) this.customer.freeWashes += 2;
        this.update(id, (o) => {
          o.status = "disputeUpheld";
          o.refund = this.refundFor(o);
          if (o.dispute) { o.dispute.outcome = "upheld"; o.dispute.decisionNote = "The after-photos show streaks on the bonnet. Raju won’t be paid for this wash."; o.dispute.creditsAwarded = 2; }
        });
      }
    });
  }

  // MARK: Gallery helpers

  markNoShowChecking() {
    const o = this.sampleOrder("onTheWay", { late: true });
    const x = this.order(o.id);
    if (x) x.noShowChecking = true;
  }

  /** An order in a given state, built from sample data, made current. */
  sampleOrder(status: OrderStatus, opt: { passMissing?: boolean; late?: boolean; cantFind?: boolean; dispute?: DisputeOutcome; damage?: boolean; skippedPhotos?: boolean } = {}): Order {
    const now = new Date();
    const o: Order = {
      id: newId("ord_sample"), ref: "WH-20914", vehicle: sampleCar(), place: homePlace(), slot: { date: startOfDay(now), startHour: 8, endHour: 10, available: true },
      price: 149, status, createdAt: now, note: { text: "", voiceSeconds: 12, videoSeconds: null }, captain: status === "searching" ? null : raju,
      arrivesBy: new Date(now.getTime() + 25 * 60000), runningLateMinutes: opt.late ? 15 : null, startedAt: new Date(now.getTime() - 22 * 60000),
      finishedAt: new Date(now.getTime() - 60000), autoApproveAt: BusinessRules.autoApproveTime(now), entryPassReceived: !opt.passMissing,
      captainCantFind: !!opt.cantFind, rating: null, paidWith: gpay, refund: null, dispute: null, usedFreeWash: false,
      customerSkippedPhotos: !!opt.skippedPhotos, noShowChecking: false, wash: null,
    };
    if (status === "noCaptain" || status === "captainNoShow") o.refund = this.autoRefund(o);
    else if (status === "cancelled" || status === "disputeUpheld") o.refund = { amount: 149, startedAt: now, method: "Google Pay · ananya@okhdfc", bankRef: "RZP8812093", credited: false, needsUPI: false, upi: null };
    if (opt.dispute) {
      o.dispute = {
        ref: opt.damage ? "WH-20915" : "WH-20914", kind: opt.damage ? "damage" : "notClean", createdAt: now,
        note: "Water streaks on the bonnet and the left mirror wasn’t wiped.", outcome: opt.dispute,
        decisionNote: opt.dispute === "upheld" ? "The after-photos show streaks on the bonnet. Raju won’t be paid for this wash." : "The scratch near the left door is visible in the 8:33 AM before-photo.",
        creditsAwarded: opt.dispute === "upheld" ? 2 : 0,
      };
    }
    this.orders = [...this.orders.filter((x) => !x.id.startsWith("ord_sample")), o];
    this.currentOrderId = o.id;
    return o;
  }

  draftBasics() { this.draft = newDraft({ type: VehicleTypes[1], plate: "TS 09 EA 4521" }); }

  draftFull() {
    this.draftBasics();
    for (const a of PhotoAngles) this.draft.photos[a] = "done";
    this.draft.videoSeconds = 14;
    this.draft.place = homePlace();
    this.draft.note = { text: "", voiceSeconds: 12, videoSeconds: null };
    this.draft.slot = { date: startOfDay(new Date()), startHour: 8, endHour: 10, available: true };
  }

  resetDemo() {
    Object.values(this.tasks).forEach((t) => t.cancel());
    this.tasks = {};
    this.demo = newDemo();
    this.backPhotoFailed = false;
    this.orders = this.orders.filter((o) => !o.id.startsWith("ord_sample"));
  }

  // MARK: Notifications (Notifications.swift)

  get unreadCount() { return this.notifications.filter((n) => !n.read).length; }
  get notificationsOn() { return this.customer?.notificationsOn ?? false; }

  /** Adds a notification to the list and, if the settings allow, shows it as a banner or a system notification. */
  notify(kind: NotificationKind, title: string, body: string, o: { orderId?: string | null; expiresAt?: Date | null; date?: Date; deliver?: boolean } = {}) {
    if (!this.customer) return;
    const date = o.date ?? new Date();
    const orderId = o.orderId ?? null;
    // Same update for the same order within a minute: keep one.
    const last = this.notifications.find((n) => n.kind === kind && n.orderId === orderId);
    if (last && date.getTime() - last.date.getTime() < 60000 && date >= last.date) return;
    const n: AppNotification = { id: newId("n"), kind, title, body, date, orderId, expiresAt: o.expiresAt ?? null, read: false };
    this.notifications = [n, ...this.notifications].sort((a, b) => b.date.getTime() - a.date.getTime());
    if (o.deliver ?? true) this.present(n);
  }

  /** Decide how (or whether) a new notification interrupts the customer. */
  private present(n: AppNotification) {
    const cat = Kind.category(n.kind);
    if (!this.notificationsOn || !(cat === "account" || this.notificationPrefs.categories.includes(cat)) || isMuted(this.notificationPrefs)) return;
    const silent = this.notificationPrefs.style === "bannerOnly" || (this.notificationPrefs.quietHours && inQuietHours());
    if (appIsActive()) {
      // Already looking at this booking: the screen updates itself, no banner needed.
      if (this.viewingOrderId != null && this.viewingOrderId === n.orderId) return;
      this.liveBanner = n;
      if (!silent) ding();
      buzz(20);
    } else if (this.systemPermission !== "denied") {
      systemNotify(n.title, n.body, silent);
    }
  }

  markRead(id: string) { const n = this.notifications.find((x) => x.id === id); if (n) n.read = true; }
  markUnread(id: string) { const n = this.notifications.find((x) => x.id === id); if (n) n.read = false; }
  markAllRead() { this.notifications.forEach((n) => { n.read = true; }); }
  deleteNotification(id: string) { this.notifications = this.notifications.filter((n) => n.id !== id); }
  clearNotifications() { this.notifications = []; }

  /** Master switch. Turning on asks the browser for permission the first time. */
  setNotifications(on: boolean) {
    if (this.customer) this.customer.notificationsOn = on;
    if (on) this.requestSystemPermission();
  }
  requestSystemPermission() { requestPermission().then((p) => { this.systemPermission = p; }); }
  refreshSystemPermission() { this.systemPermission = systemPermission(); }
  mute(seconds: number | null) { this.notificationPrefs.mutedUntil = seconds == null ? null : new Date(Date.now() + seconds * 1000); }
  /** Mute until 8 AM tomorrow. */
  muteUntilMorning() { const d = addDays(startOfDay(new Date()), 1); d.setHours(8); this.notificationPrefs.mutedUntil = d; }

  /** Emits notifications for meaningful changes to an order (called from `update`). */
  private notifyChanges(old: { status: OrderStatus; late: number | null; checking: boolean; cantFind: boolean; credited: boolean }, o: Order) {
    const name = o.captain?.name ?? "Your captain";
    const price = Fmt.rupees(o.price);
    const id = { orderId: o.id };
    if (old.status !== o.status) {
      switch (o.status) {
        case "searching":
          this.notify("bookingConfirmed", "Booking confirmed", `${o.vehicle.plate} · ${Slot.full(o.slot)}. We’re finding a captain.`, id);
          if (!o.entryPassReceived) this.notify("gatePassNeeded", "Share your gate pass", "Reply on WhatsApp with your MyGate or society pass so the captain can get in.", { ...id, date: new Date(Date.now() + 1000) });
          break;
        case "onTheWay":
          this.notify("captainAssigned", `${name} is on the way`, `Arriving by ${Fmt.time(o.arrivesBy ?? new Date())} for ${o.vehicle.plate}.`, id); break;
        case "washing":
          this.notify("washStarted", "Washing has started", `${name} started at ${Fmt.time(o.startedAt ?? new Date())}. Photos when he’s done.`, id); break;
        case "photosReady":
          this.notify("photosReady", "Check the wash", `Photos are ready. Approve to release ${price} to ${name}, or tell us if something’s wrong.`, id); break;
        case "autoApproved":
          this.notify("autoApproved", "Wash approved automatically", `${price} went to ${name}. You can still report a problem until midnight tomorrow.`, id); break;
        case "noCaptain":
          this.notify("noCaptain", "No captain could take your wash", awaitingUPI(o.refund)
            ? `We’ve cancelled it. Tell us your UPI ID and we’ll send your ${price} back.`
            : `We’ve cancelled it. Your ${price} is on its way to ${o.refund?.upi ?? "your UPI"}.`, id); break;
        case "captainNoShow":
          this.notify("noShowRefund", "Full refund for your missed wash", awaitingUPI(o.refund)
            ? `${name} didn’t turn up. Add your UPI ID and ${price} reaches you by 11:59 PM.`
            : `${name} didn’t turn up. ${price} goes to ${o.refund?.upi ?? "your UPI"} by 11:59 PM. We’ve taken action with the captain.`, id); break;
        case "cancelled":
          this.notify("bookingCancelled", "Booking cancelled", `Your refund of ${Fmt.rupees(o.refund?.amount ?? o.price)} has started.`, id); break;
        case "disputeUpheld": case "disputeRejected":
          this.notify("disputeDecision", "We’ve checked your report", `Tap to see the decision for ${o.vehicle.plate}.`, id); break;
        case "paymentPending":
          this.notify("paymentPending", "Payment not confirmed yet", "If money left your account, it comes back within 3 days.", id); break;
        default: break;
      }
    }
    if (old.late == null && o.runningLateMinutes != null) {
      this.notify("captainRunningLate", "Your wash is running late", `${name} is about ${o.runningLateMinutes} min behind. We’ll keep you posted.`, id);
    }
    if (!old.checking && o.noShowChecking) {
      this.notify("washStatusCheck", "We’re checking on your wash", `Your slot has ended and ${name} hasn’t updated the wash. We’re checking with him and will update you.`, id);
    }
    if (!old.cantFind && o.captainCantFind) {
      this.notify("captainCantFind", `${name} can’t find your vehicle`, `He’s at ${PlaceFmt.parkingShort(o.place)}. Tell him where it is.`, id);
    }
    if (!old.credited && o.refund?.credited) {
      this.notify("refundCredited", "Refund credited", `${Fmt.rupees(o.refund.amount)} reached ${o.refund.method}.`, id);
    }
  }

  /** Sample inbox for the demo customer: one of each kind, including edge cases. */
  seedSampleNotifications() {
    const now = Date.now();
    const h = (x: number) => new Date(now - x * 3600000);
    const car = sampleCar().plate;
    const mk = (id: string, kind: NotificationKind, title: string, body: string, date: Date, extra: Partial<AppNotification> = {}): AppNotification =>
      ({ id, kind, title, body, date, orderId: null, expiresAt: null, read: false, ...extra });
    this.notifications = [
      mk("n_offer", "offer", "Weekend shine, ₹20 off", "On wet washes this Saturday and Sunday.", h(0.4), { expiresAt: new Date(now + 3 * 86400000) }),
      mk("n_free", "freeWash", "You’ve got a free wash", "Thanks for the report last week. It’s applied at checkout.", h(5)),
      mk("n_photos_old", "photosReady", "Check the wash", `Photos are ready for ${car}. Approve to release ₹149 to Raju.`, h(26), { orderId: "ord_past1", read: true }),
      mk("n_assigned_old", "captainAssigned", "Raju is on the way", `Arriving by 8:40 AM for ${car}.`, h(27), { orderId: "ord_past1", read: true }),
      mk("n_refund", "refundCredited", "Refund credited", "₹149 reached Google Pay · ananya@okhdfc.", h(70), { orderId: "ord_past2" }),
      mk("n_gone", "bookingConfirmed", "Booking confirmed", "TS 09 AB 1234 · Mon, 8 – 10 AM.", h(140), { orderId: "ord_removed", read: true }),
      mk("n_offer_old", "offer", "Diwali double shine", "Two washes for the price of one.", h(240), { expiresAt: new Date(now - 5 * 86400000), read: true }),
      mk("n_phone", "phoneChanged", "Your phone number was changed", "If this wasn’t you, contact us right away.", h(300), { read: true }),
      mk("n_welcome", "welcome", `Welcome to ${Brand.name}`, "Book a wash, see the photos, then pay. That’s it.", h(600), { read: true }),
    ].sort((a, b) => b.date.getTime() - a.date.getTime());
  }
}

/** Shared tap behaviour for a notification (list row, banner). Returns an info message, if any. */
export function openNotification(n: AppNotification, store: AppStore, router: Router): string | null {
  store.markRead(n.id);
  store.liveBanner = null;
  switch (n.kind) {
    case "offer":
      if (n.expiresAt && n.expiresAt.getTime() < Date.now()) return "This offer has ended.";
      store.startNewBooking();
      router.push({ n: "vehicleType" });
      return null;
    case "freeWash":
      store.startNewBooking();
      router.push({ n: "vehicleType" });
      return null;
    case "phoneChanged":
      router.popToRoot(); router.tab = 3;
      return null;
    case "welcome":
      return null;
    default: break;
  }
  const o = n.orderId ? store.order(n.orderId) : null;
  if (!o) return "This booking isn’t available anymore. It may have been removed.";
  store.currentOrderId = o.id;
  switch (n.kind) {
    case "noCaptain": case "noShowRefund":
      if (awaitingUPI(o.refund)) router.push({ n: "refundUPI", id: o.id });
      else if (o.refund) router.push({ n: "refund" }); else router.push({ n: "live" });
      break;
    case "refundCredited": case "bookingCancelled":
      router.push(o.refund ? { n: "refund" } : { n: "live" });
      break;
    case "disputeDecision":
      router.push({ n: "disputeStatus" });
      break;
    case "gatePassNeeded":
      if (o.entryPassReceived || !Status.isActive(o.status)) { store.toast = "Gate pass already received. Here’s the latest."; router.push({ n: "live" }); }
      else router.push({ n: "whatsApp" });
      break;
    case "paymentPending":
      if (o.status === "paymentPending") router.push({ n: "paying", view: "pending" });
      else { store.toast = "Good news: the payment went through."; router.push({ n: "live" }); }
      break;
    default: {
      const s = Kind.liveStatuses(n.kind);
      if (s && !s.includes(o.status)) store.toast = "Things have moved on. Here’s the latest.";
      router.push({ n: "live" });
    }
  }
  return null;
}

/** Creates the app's store and router, wired to one change hub. */
export function createCustomerApp() {
  const hub = new Hub();
  const store = reactive(new AppStore(), hub);
  const router = reactive(new Router(), hub);
  return { hub, store, router };
}
