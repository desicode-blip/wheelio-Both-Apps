// Formatting helpers (Indian English), ported from apps/ios/Shared/Formatting.swift. Money is whole rupees.

import { call } from "./device";

const inr = new Intl.NumberFormat("en-IN");
const hour12 = (h: number) => (h % 12 === 0 ? 12 : h % 12);
const ampm = (h: number) => (h % 24 < 12 ? "AM" : "PM");
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

export const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
export const addDays = (d: Date, n: number) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n, d.getHours(), d.getMinutes(), d.getSeconds());
export const dayDiff = (from: Date, to: Date) => Math.round((startOfDay(to).getTime() - startOfDay(from).getTime()) / 86400000);
export const isToday = (d: Date) => dayDiff(new Date(), d) === 0;
export const isYesterday = (d: Date) => dayDiff(new Date(), d) === -1;

export const Fmt = {
  rupees: (amount: number) => (amount < 0 ? "−₹" : "₹") + inr.format(Math.abs(amount)),
  clock: (seconds: number) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`,
  /** "8 – 10 AM" when both ends share AM/PM, otherwise "10 AM – 12 PM". */
  window: (start: number, end: number) =>
    ampm(start) === ampm(end) ? `${hour12(start)} – ${hour12(end)} ${ampm(end)}` : `${hour12(start)} ${ampm(start)} – ${hour12(end)} ${ampm(end)}`,
  /** "8:40 AM" */
  time: (d: Date) => `${hour12(d.getHours())}:${String(d.getMinutes()).padStart(2, "0")} ${ampm(d.getHours())}`,
  /** "Mon, 12 Oct" */
  date: (d: Date) => `${DAYS[d.getDay()]}, ${d.getDate()} ${MONTHS[d.getMonth()]}`,
  /** "Today", "Tomorrow" or "Mon, 12 Oct". */
  day: (d: Date) => {
    const diff = dayDiff(new Date(), d);
    if (diff === 0) return "Today";
    if (diff === 1) return "Tomorrow";
    if (diff === -1) return "Yesterday";
    return Fmt.date(d);
  },
  /** "+91 98480 11223" */
  phone: (ten: string) => (ten.length === 10 ? `+91 ${ten.slice(0, 5)} ${ten.slice(5)}` : `+91 ${ten}`),
  /** "98480 11223" */
  phoneShort: (ten: string) => (ten.length === 10 ? `${ten.slice(0, 5)} ${ten.slice(5)}` : ten),
};

/** Input rules shared by both apps. */
export const Validators = {
  normalisePlate: (s: string) => s.toUpperCase().replace(/[^A-Z0-9]/g, ""),
  digitsOnly: (s: string) => s.replace(/[^0-9]/g, ""),
  /** The only phone check: exactly 10 digits (the first 10 the person typed). */
  isValidMobile: (s: string) => Validators.digitsOnly(s).length === 10,
  /** UPI ID like name@okhdfc or 9876543210@ybl. */
  isValidUPI: (s: string) => /^[A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9]{1,63}$/.test(s.trim()),
  isValidName: (s: string) => {
    const t = s.trim();
    return t.length >= 2 && t.length <= 40;
  },
};

/** Support details (placeholders until the real numbers exist). */
const SUPPORT_PHONE = "+910000000000";

export const Support = {
  phone: SUPPORT_PHONE,
  hours: "7 AM – 9 PM, every day. Calls in English, Hindi or Telugu.",
  call: (number: string = SUPPORT_PHONE) => call(number),
};

export const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

let uid = 0;
export const newId = (prefix = "id") => `${prefix}_${Date.now().toString(36)}${(uid++).toString(36)}`;
