// Domain models, ported from apps/ios/Customer/Data/Models.swift. Field names mirror the backend.

import { Fmt, startOfDay } from "../lib/fmt";
import type { IconName } from "../ds/icons";

export type VehicleKind = "bike" | "hatchback" | "sedan" | "suv";

/** Kind of wash, chosen right after the vehicle. Same price for every option. */
export type WashKind = "dryDusting" | "wetOutside" | "wetOutsideDryInside";

export const Wash = {
  name: (w: WashKind, bike: boolean) =>
    w === "dryDusting" ? (bike ? "Dusting" : "Dry wash (dusting)") : w === "wetOutside" ? (bike ? "Wet wash" : "Wet wash, outside") : "Wet outside + dry clean inside",
  detail: (w: WashKind, bike: boolean) =>
    w === "dryDusting" ? "Dust wiped off with a dry cloth. No water." : w === "wetOutside" ? (bike ? "Water and cloth, then wiped dry." : "Body, glass and wheels. Water and cloth.") : "Wet wash outside, seats and mats dusted inside.",
  short: (w: WashKind) => (w === "dryDusting" ? "Dusting" : w === "wetOutside" ? "Wet wash" : "Wet + inside"),
  icon: (w: WashKind): IconName => (w === "dryDusting" ? "wipe" : w === "wetOutside" ? "drop" : "sparkle"),
  /** Interior cleaning isn't offered in any society yet. */
  available: (w: WashKind) => w !== "wetOutsideDryInside",
  options: (k?: VehicleKind | null): WashKind[] => (k === "bike" ? ["dryDusting", "wetOutside"] : ["dryDusting", "wetOutside", "wetOutsideDryInside"]),
};

export type VehicleType = { kind: VehicleKind; name: string; minutes: number; price: number };

export const VehicleTypes: VehicleType[] = [
  { kind: "bike", name: "Bike or scooter", minutes: 15, price: 69 },
  { kind: "hatchback", name: "Hatchback", minutes: 20, price: 149 },
  { kind: "sedan", name: "Sedan or compact SUV", minutes: 20, price: 179 },
  { kind: "suv", name: "SUV or MUV", minutes: 25, price: 219 },
];

export const VT = {
  short: (t: VehicleType) => ({ bike: "Scooter", hatchback: "Hatchback", sedan: "Sedan", suv: "SUV" })[t.kind],
  icon: (t: VehicleType): IconName => (t.kind === "bike" ? "bike" : t.kind === "suv" ? "suv" : "car"),
};

export type Society = { id: string; name: string; area: string; city: string; pincode: string };

/** Where the vehicle is parked. */
export type Place = { society: Society; tower: string; floor: string | null; slot: string };

export const PlaceFmt = {
  title: (p: Place) => (p.tower ? `${p.society.name}, ${p.tower}` : p.society.name),
  addressLine: (p: Place) => `${p.society.area}, ${p.society.city}${p.society.pincode ? ` ${p.society.pincode}` : ""}`,
  /** "B2, slot 41" */
  parkingShort: (p: Place) => {
    const f = p.floor ?? "";
    if (!p.slot) return f;
    return f ? `${f}, slot ${p.slot}` : `slot ${p.slot}`;
  },
  key: (p: Place) => `${p.society.id}|${p.tower}|${p.floor ?? ""}|${p.slot}`,
};

export type Vehicle = { id: string; plate: string; type: VehicleType; place: Place | null };

export type PhotoAngle = "front" | "back" | "left" | "right";
export const PhotoAngles: PhotoAngle[] = ["front", "back", "left", "right"];
export const angleLabel = (a: PhotoAngle) => ({ front: "Front", back: "Back", left: "Left side", right: "Right side" })[a];

export type UploadState = "uploading" | "done" | "failed";

/** Note for the captain: text, voice or video. */
export type EntryNote = { text: string; voiceSeconds: number | null; videoSeconds: number | null };
export const emptyNote = (): EntryNote => ({ text: "", voiceSeconds: null, videoSeconds: null });
export const Note = {
  isEmpty: (n: EntryNote) => !n.text.trim() && n.voiceSeconds == null && n.videoSeconds == null,
  summary: (n: EntryNote) => {
    if (n.voiceSeconds != null) return `Voice note · ${Fmt.clock(n.voiceSeconds)}`;
    if (n.videoSeconds != null) return `Video · ${Fmt.clock(n.videoSeconds)}`;
    return n.text.trim() || "None";
  },
};

/** A wash window on a given day. */
export type TimeSlot = { date: Date; startHour: number; endHour: number; available: boolean };
export const Slot = {
  label: (s: TimeSlot) => Fmt.window(s.startHour, s.endHour),
  day: (s: TimeSlot) => Fmt.day(s.date),
  /** "Today, 8 – 10 AM" */
  full: (s: TimeSlot) => `${Fmt.day(s.date)}, ${Fmt.window(s.startHour, s.endHour)}`,
  start: (s: TimeSlot) => { const d = startOfDay(s.date); d.setHours(s.startHour); return d; },
  end: (s: TimeSlot) => { const d = startOfDay(s.date); d.setHours(s.endHour % 24); return d; },
  same: (a: TimeSlot | null | undefined, b: TimeSlot | null | undefined) =>
    !!a && !!b && a.date.getTime() === b.date.getTime() && a.startHour === b.startHour && a.endHour === b.endHour,
};

export type Customer = { id: string; phone: string; name: string; freeWashes: number; notificationsOn: boolean; refundUPI: string | null };
export const Cust = {
  firstName: (c: Customer) => c.name.split(" ").filter(Boolean)[0] ?? "",
  initials: (c: Customer) => {
    const p = c.name.split(" ").filter(Boolean);
    if (!p.length) return "?";
    if (p.length === 1) return p[0][0].toUpperCase();
    return (p[0][0] + p[p.length - 1][0]).toUpperCase();
  },
};

export type Captain = { id: string; name: string; rating: number; washes: number; initials: string };

/** Order lifecycle. */
export type OrderStatus =
  | "pendingPayment" | "paymentPending" | "searching" | "onTheWay" | "washing" | "photosReady" | "approved" | "autoApproved"
  | "disputed" | "disputeUpheld" | "disputeRejected" | "cancelled" | "noCaptain" | "captainNoShow";

export const Status = {
  isActive: (s: OrderStatus) => ["searching", "onTheWay", "washing", "photosReady"].includes(s),
  isUpcoming: (s: OrderStatus) => Status.isActive(s) || s === "paymentPending",
  /** Index into the 4 customer-visible steps. */
  step: (s: OrderStatus) => ({ searching: 0, onTheWay: 1, washing: 2, photosReady: 3 } as Record<string, number>)[s] ?? 4,
};

export type PaymentMethod = { id: string; title: string; detail: string };
export type PaymentOutcome = "success" | "failed" | "pending";

export type Refund = {
  amount: number; startedAt: Date; method: string; bankRef: string; credited: boolean;
  /** Automatic cancellations refund to a UPI ID the customer gives us. */
  needsUPI: boolean; upi: string | null;
};
export const awaitingUPI = (r?: Refund | null) => !!r && r.needsUPI && r.upi == null;

export type ProblemKind = "notClean" | "damage" | "wrongVehicle" | "noShow";
export const ProblemKinds: ProblemKind[] = ["notClean", "damage", "wrongVehicle", "noShow"];
export const Problem = {
  title: (k: ProblemKind) => ({ notClean: "Not clean enough", damage: "Something got damaged", wrongVehicle: "Wrong vehicle washed", noShow: "Captain didn’t come" })[k],
  subtitle: (k: ProblemKind) => ({ notClean: "Spots, dust or streaks left", damage: "Scratch, dent or broken part", wrongVehicle: "Not my car or bike", noShow: "But it says done" })[k],
  icon: (k: ProblemKind): IconName => ({ notClean: "drop", damage: "scratch", wrongVehicle: "car", noShow: "close" } as const)[k],
};

export type DisputeOutcome = "underReview" | "upheld" | "rejected" | "damagePriority";
export type Dispute = { ref: string; kind: ProblemKind; createdAt: Date; note: string; outcome: DisputeOutcome; decisionNote: string; creditsAwarded: number };

export type Order = {
  id: string; ref: string; vehicle: Vehicle; place: Place; slot: TimeSlot; price: number; status: OrderStatus; createdAt: Date;
  note: EntryNote; captain: Captain | null; arrivesBy: Date | null; runningLateMinutes: number | null; startedAt: Date | null;
  finishedAt: Date | null; autoApproveAt: Date | null; entryPassReceived: boolean; captainCantFind: boolean; rating: number | null;
  paidWith: PaymentMethod | null; refund: Refund | null; dispute: Dispute | null; usedFreeWash: boolean;
  /** The customer skipped their own photos at booking. */
  customerSkippedPhotos: boolean;
  /** Slot window passed and the captain hasn't updated the wash: we're checking with him. */
  noShowChecking: boolean;
  wash: WashKind | null;
};

export const Ord = {
  washKind: (o: Order): WashKind => o.wash ?? "wetOutside",
  /** Report allowed until this time (approval + dispute window). */
  reportUntil: (o: Order) => (o.finishedAt ? new Date(o.finishedAt.getTime() + 26 * 3600000) : null),
  vehicleLine: (o: Order) => `${o.vehicle.plate} · ${VT.short(o.vehicle.type)}`,
};

/** Business values not decided yet. While null the UI shows the placeholder text from the designs. */
export const BusinessRules = {
  cancellationFee: null as number | null,
  waitFee: null as number | null,
  /** Washes auto-approve at 12 midnight on the day they finish (the captain payout run). */
  autoApproveTime: (finished: Date) => { const d = startOfDay(finished); d.setDate(d.getDate() + 1); return d; },
  get cancellationFeeText() { return BusinessRules.cancellationFee != null ? String(BusinessRules.cancellationFee) : "[CANCELLATION FEE]"; },
  refundAmountText: "[REFUND AMOUNT]",
};
