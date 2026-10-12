"use client";

// Pieces shared by several customer screens: headers, captain card, status badge, bell, photo picker.

import { createContext, useContext, useState } from "react";
import { C, S } from "../../ds/tokens";
import { ActionSheet, AppBar, Avatar, Badge, HStack, IconButton, Progress, Tap, T, TD, VStack, card } from "../../ds/components";
import { Icon } from "../../ds/icons";
import { Fmt, Support } from "../../lib/fmt";
import { pickImage } from "../../lib/device";
import { Ord, Slot, type Order, type OrderStatus } from "../model";
import { useApp } from "../ctx";

/** Total steps shown in BookingHeader ("Step 1 of 2"). */
export const StepTotal = createContext(5);

/** Header used by every booking step: app bar + "Step n of 5 · Label". */
export function BookingHeader({ step, label, title = "Book a wash", fraction }: { step: number; label: string; title?: string; fraction?: number }) {
  const { router } = useApp();
  const total = useContext(StepTotal);
  const f = fraction ?? step / total;
  return (
    <VStack gap={8} style={{ paddingTop: 4 }}>
      <AppBar title={title} onLeading={() => router.pop()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "0 14px" }} />
      <div style={{ padding: `0 ${S.gutter}px` }}>
        <Progress step={Math.round(f * 100)} of={100} label={`Step ${step} of ${total} · ${label}`} />
      </div>
    </VStack>
  );
}

/** Plain header with back and help, no title (login screens). */
export function PlainHeader({ leading = "left" as const }: { leading?: "left" | "close" | null }) {
  const { router } = useApp();
  return <AppBar leading={leading} onLeading={() => router.pop()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "4px 14px 0" }} />;
}

/** Order header: "Today, 8 – 10 AM" over "TS 09 EA 4521 · Hatchback". */
export function OrderHeader({ order, onBack }: { order: Order; onBack?: () => void }) {
  const { router } = useApp();
  return (
    <AppBar title={Slot.full(order.slot)} subtitle={Ord.vehicleLine(order)} style={{ padding: "4px 14px 0" }}
      onLeading={() => (onBack ? onBack() : router.popToRoot())} onTrailing={() => router.push({ n: "help" })} />
  );
}

/** Captain card: avatar, name, rating, call button, status badge and time. */
export function CaptainCard({ order, badge, timeText, style }: { order: Order; badge: React.ReactNode; timeText: string; style?: React.CSSProperties }) {
  const c = order.captain;
  return (
    <VStack gap={14} style={{ ...card(16), ...style }}>
      <HStack gap={12}>
        <Avatar initials={c?.initials ?? "RY"} size={50} />
        <VStack gap={2} style={{ flex: 1 }}>
          <TD k="title" w={600} s={17}>{c?.name ?? "Raju"}</TD>
          <HStack gap={4}>
            <Icon name="starFill" size={12} color={C.star} />
            <T k="caption">{`${(c?.rating ?? 4.8).toFixed(1)} · ${c?.washes ?? 212} washes`}</T>
          </HStack>
        </VStack>
        <IconButton icon="phone" style="tint" label={`Call ${c?.name ?? "captain"}`} onClick={() => Support.call()} />
      </HStack>
      <HStack>
        {badge}
        <div style={{ flex: 1 }} />
        <T k="caption" c={C.heading} w={500}>{timeText}</T>
      </HStack>
    </VStack>
  );
}

/** "₹149 is held safely. It's released to the captain only after you approve the after-photos." */
export function HeldSafelyBanner({ amount, style }: { amount: number; style?: React.CSSProperties }) {
  return (
    <HStack align="start" gap={12} style={{ padding: 16, borderRadius: 14, background: C.primaryTint, ...style }}>
      <Icon name="shield" size={17} color={C.heading} style={{ marginTop: 2 }} />
      <TD k="caption" c={C.inverse} s={14}>
        <span style={{ fontWeight: 600 }}>{Fmt.rupees(amount)} is held safely. </span>
        It’s released to the captain only after you approve the after-photos.
      </TD>
    </HStack>
  );
}

/** Status badge for an order (icon + word). */
export function StatusBadge({ status }: { status: OrderStatus }) {
  switch (status) {
    case "searching": return <Badge text="Searching" tone="mute" icon="search" />;
    case "onTheWay": return <Badge text="On the way" tone="info" icon="check" />;
    case "washing": return <Badge text="Washing" tone="info" icon="drop" />;
    case "photosReady": return <Badge text="Check photos" tone="ok" icon="image" />;
    case "approved": case "autoApproved": case "disputeRejected": return <Badge text="Done" tone="ok" icon="sparkle" />;
    case "cancelled": return <Badge text="Cancelled" tone="error" icon="close" />;
    case "noCaptain": case "disputeUpheld": case "captainNoShow": return <Badge text="Refunded" tone="ok" icon="rupee" />;
    case "disputed": return <Badge text="Under review" tone="wait" icon="eye" />;
    case "paymentPending": return <Badge text="Payment pending" tone="wait" icon="clock" />;
    case "pendingPayment": return <Badge text="Not paid" tone="mute" icon="clock" />;
  }
}

/** Bell with unread count, for the Home header. */
export function NotificationBell() {
  const { store, router } = useApp();
  const n = store.unreadCount;
  return (
    <Tap onClick={() => router.push({ n: "notifications" })} label={n > 0 ? `Notifications, ${n} unread` : "Notifications"}
      style={{ position: "relative", width: 44, height: 44, display: "grid", placeItems: "center" }}>
      <Icon name={store.notificationsOn ? "bell" : "bellSlash"} size={22} />
      {n > 0 && (
        <span style={{ position: "absolute", top: 4, right: 2, minWidth: 17, height: 17, padding: "0 5px", borderRadius: 9, background: C.destructive, color: "#fff", fontSize: 10, fontWeight: 700, display: "grid", placeItems: "center", boxSizing: "border-box" }}>
          {n > 9 ? "9+" : n}
        </span>
      )}
    </Tap>
  );
}

/** Tap the profile circle to pick a photo. Long-press to remove it. */
export function ProfilePhotoPicker({ initials, size = 56 }: { initials: string; size?: number }) {
  const { store } = useApp();
  const [menu, setMenu] = useState(false);
  return (
    <>
      <Tap label={store.profilePhoto ? "Change profile photo" : "Add a profile photo"}
        onClick={async () => { const d = await pickImage(); if (d) store.profilePhoto = d; }}
        onContext={() => { if (store.profilePhoto) setMenu(true); }}
        style={{ position: "relative", width: size, height: size, flexShrink: 0 }}>
        <Avatar initials={initials} size={size} photo={store.profilePhoto} />
        <span style={{ position: "absolute", right: -2, bottom: -2, width: 22, height: 22, borderRadius: 11, background: C.primary, boxShadow: "0 0 0 2px #fff", display: "grid", placeItems: "center" }}>
          <Icon name="camera" size={11} color="#fff" />
        </span>
      </Tap>
      <ActionSheet open={menu} onClose={() => setMenu(false)} actions={[{ title: "Remove photo", role: "destructive", action: () => { store.profilePhoto = null; } }]} />
    </>
  );
}
