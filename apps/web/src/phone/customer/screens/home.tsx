"use client";

import { useEffect, useState } from "react";
import { C, S } from "../../ds/tokens";
import {
  Alert, Avatar, Badge, Banner, BottomNav, Button, Divider, FullState, HStack, IconBox, KeyValueCard, ListRow, PhotoPlaceholder, Plate,
  Progress, Screen, StateCircle, Tabs, Tap, T, TD, TitleBlock, VStack, AppBar, FooterBar, card, outlined,
} from "../../ds/components";
import { Icon, type IconName } from "../../ds/icons";
import { Fmt } from "../../lib/fmt";
import { useOnAppear, useApp, callSupport } from "../ctx";
import { Cust, Note, Ord, PlaceFmt, Slot, Status, VT, Wash, emptyNote, type Order } from "../model";
import { isMuted, sampleCar } from "../store";
import { BookingHeader, NotificationBell, PlainHeader, ProfilePhotoPicker, StatusBadge } from "./parts";
import { BrandMark } from "./start";

// MARK: Tabs

export function MainTabs() {
  const { store, router } = useApp();
  return (
    <div className="wh-fill" style={{ background: C.canvas }}>
      <div style={{ flex: 1, minHeight: 0, position: "relative" }}>
        {router.tab === 1 ? <BookingsTab /> : router.tab === 2 ? <VehiclesTab /> : router.tab === 3 ? <ProfileTab /> : <HomeTab />}
      </div>
      <BottomNav
        selection={router.tab}
        onSelect={(t) => { router.tab = t; }}
        items={[
          { id: 0, title: "Home", icon: "home" },
          { id: 1, title: "Bookings", icon: "calendar", badge: store.activeOrder ? 1 : 0 },
          { id: 2, title: "Vehicles", icon: "car" },
          { id: 3, title: "Profile", icon: "user" },
        ]}
      />
    </div>
  );
}

const TabScroll = ({ children }: { children: React.ReactNode }) => (
  <div className="wh-scroll" style={{ position: "absolute", inset: 0, background: C.canvas, paddingTop: "var(--sat)" }}>
    <div style={{ padding: `0 ${S.gutter}px 24px`, display: "flex", flexDirection: "column" }}>{children}</div>
  </div>
);

// MARK: C40 / C41 / C42 Home (C55 loading)

type BookAgainEntry = { order: Order; placeDiffers: boolean; washDiffers: boolean };

export function HomeTab() {
  const { store, router } = useApp();
  const [loading, setLoading] = useState(true);
  useEffect(() => { const t = setTimeout(() => setLoading(false), 600); return () => clearTimeout(t); }, []);

  const book = () => { store.startNewBooking(); router.push({ n: "vehicleType" }); };
  const c = store.customer;

  /** One entry per vehicle + place + wash, newest first. */
  const entries: BookAgainEntry[] = (() => {
    const seen = new Set<string>();
    const list: BookAgainEntry[] = [];
    for (const o of store.pastOrders) {
      const key = `${o.vehicle.id}#${PlaceFmt.key(o.place)}#${Ord.washKind(o)}`;
      if (!seen.has(key)) { seen.add(key); list.push({ order: o, placeDiffers: false, washDiffers: false }); }
    }
    for (const e of list) {
      const sib = list.filter((x) => x.order.vehicle.id === e.order.vehicle.id && x.order.id !== e.order.id);
      e.placeDiffers = sib.some((x) => PlaceFmt.key(x.order.place) !== PlaceFmt.key(e.order.place));
      e.washDiffers = sib.some((x) => Ord.washKind(x.order) !== Ord.washKind(e.order));
    }
    return list;
  })();

  const highlight = (text: string, on: boolean, icon?: IconName) => (
    <HStack gap={4} style={{ padding: on ? "3px 8px" : 0, borderRadius: 999, background: on ? C.primaryTint : "transparent", alignSelf: "flex-start" }}>
      {icon && <Icon name={icon} size={12} color={on ? C.primaryStrong : C.secondary} />}
      <T k="caption" c={on ? C.primaryStrong : undefined} w={on ? 600 : undefined} lines={2}>{text}</T>
    </HStack>
  );

  const activeTitle = (o: Order) => {
    const n = o.captain?.name ?? "Captain";
    return ({ searching: "Finding a captain", onTheWay: `${n} is on the way`, washing: `${n} is washing`, photosReady: "Check the photos" } as Record<string, string>)[o.status] ?? "Booking";
  };

  const skeleton = (
    <VStack gap={18} style={{ opacity: 0.9 }}>
      <div style={{ width: 160, height: 26, borderRadius: 8, background: C.disabled, marginTop: 18 }} />
      <VStack gap={14} style={card(18)}>
        <div style={{ width: 120, height: 12, borderRadius: 6, background: C.disabled }} />
        <HStack gap={12}>
          <div style={{ width: 40, height: 40, borderRadius: 20, background: C.disabled }} />
          <VStack gap={8}>
            <div style={{ width: 180, height: 12, borderRadius: 6, background: C.disabled }} />
            <div style={{ width: 130, height: 10, borderRadius: 6, background: C.disabled }} />
          </VStack>
        </HStack>
      </VStack>
      {[0, 1].map((i) => <div key={i} style={{ ...card(16), height: 82 }} />)}
    </VStack>
  );

  const hasHistory = store.pastOrders.length > 0 || store.activeOrder != null;
  const a = store.activeOrder;

  return (
    <TabScroll>
      <HStack style={{ paddingTop: 14 }}>
        <BrandMark />
        <div style={{ flex: 1 }} />
        <NotificationBell />
      </HStack>
      {loading ? skeleton : (
        <div className="wh-fade-in" style={{ display: "flex", flexDirection: "column" }}>
          <TD k="screen" style={{ paddingTop: 18 }}>{!c || !Cust.firstName(c) ? "Hi there" : `Hi ${Cust.firstName(c)}`}</TD>
          {!hasHistory || !c ? (
            <>
              <TD k="body" style={{ paddingTop: 4 }}>Your wheels are waiting.</TD>
              <VStack style={{ ...card(20), marginTop: 24 }}>
                <div style={{ paddingBottom: 22 }}><StateCircle icon="drop" size={64} /></div>
                <TD k="section" w={600}>Book your first wash</TD>
                <TD k="body" style={{ paddingTop: 6, paddingBottom: 20 }}>Car from ₹149, bike ₹69. Pay only after you see the photos.</TD>
                <Button title="Book a wash" onClick={book} />
              </VStack>
              <VStack gap={16} style={{ marginTop: 34 }}>
                <TD k="section" w={600}>How it works</TD>
                {["Tell us where it’s parked and pick a time", "A verified captain cleans it, before and after photos", "You approve the photos, then the captain is paid"].map((t, i) => (
                  <HStack key={i} gap={14}>
                    <span style={{ width: 32, height: 32, borderRadius: 16, background: C.primaryTint, display: "grid", placeItems: "center", flexShrink: 0 }}><T k="label" c={C.primaryStrong}>{i + 1}</T></span>
                    <T k="bodyStrong" s={15.5}>{t}</T>
                  </HStack>
                ))}
              </VStack>
            </>
          ) : (
            <>
              {(c.freeWashes ?? 0) > 0 && (
                <Banner tone="ok" icon="gift" title={`You have ${c.freeWashes} free washes.`} text="They’re applied at checkout." actionTitle="Use one" onAction={book} style={{ marginTop: 20 }} />
              )}
              {/* Booking a wash is always the main action, even while another wash is running. */}
              <VStack gap={16} style={{ ...card(20), marginTop: 20 }}>
                <TD k="section" w={600}>Book a wash</TD>
                <Button title="Book a wash" onClick={book} />
              </VStack>
              {a && (
                <>
                  <TD k="section" w={600} style={{ paddingTop: 30, paddingBottom: 14 }}>In progress</TD>
                  <Tap onClick={() => { store.currentOrderId = a.id; router.push({ n: "live" }); }} style={{ ...card(16, 16), display: "flex", flexDirection: "column", gap: 12, textAlign: "left" }}>
                    <HStack>
                      <T k="label" c={C.heading}>{`${Slot.day(a.slot)} · ${Slot.label(a.slot)}`}</T>
                      <div style={{ flex: 1 }} />
                      <StatusBadge status={a.status} />
                    </HStack>
                    <HStack gap={12}>
                      <Avatar initials={a.captain?.initials ?? "…"} size={40} />
                      <VStack gap={1} style={{ flex: 1 }}>
                        <TD k="title" w={500}>{activeTitle(a)}</TD>
                        <TD k="caption">{`${a.vehicle.plate} · ${PlaceFmt.parkingShort(a.place)}`}</TD>
                      </VStack>
                      <Icon name="chevron" size={15} color={C.secondary} />
                    </HStack>
                    <Progress step={Status.step(a.status) + 1} of={4} />
                  </Tap>
                </>
              )}
            </>
          )}
          {c && entries.length > 0 && (
            <>
              <TD k="section" w={600} style={{ paddingTop: 30, paddingBottom: 14 }}>Book again</TD>
              <VStack gap={12}>
                {entries.map((e) => {
                  const o = e.order;
                  const bike = o.vehicle.type.kind === "bike";
                  return (
                    <Tap key={o.id} onClick={() => router.push({ n: "repeatBooking", id: o.id })} style={{ ...card(16, 16), display: "flex", alignItems: "flex-start", gap: 14, textAlign: "left" }}>
                      <IconBox icon={VT.icon(o.vehicle.type)} size={48} radius={12} />
                      <VStack gap={6} style={{ flex: 1, minWidth: 0 }}>
                        <HStack>
                          <Plate text={o.vehicle.plate} />
                          <div style={{ flex: 1, minWidth: 8 }} />
                          <T k="valueStrong" mono>{Fmt.rupees(o.price)}</T>
                        </HStack>
                        <HStack gap={4}>
                          <T k="caption">{`${VT.short(o.vehicle.type)} ·`}</T>
                          {highlight(Wash.name(Ord.washKind(o), bike), e.washDiffers)}
                        </HStack>
                        {highlight(`${PlaceFmt.title(o.place)} · ${PlaceFmt.parkingShort(o.place)}`, e.placeDiffers, "location")}
                        <T k="small" c={C.muted}>{`Last booked ${Fmt.day(o.slot.date)}`}</T>
                      </VStack>
                      <Icon name="chevron" size={15} color={C.secondary} style={{ marginTop: 10 }} />
                    </Tap>
                  );
                })}
              </VStack>
            </>
          )}
        </div>
      )}
    </TabScroll>
  );
}

// MARK: C43 Bookings (C43b empty, C43c past)

export function BookingsTab() {
  const { store, router } = useApp();
  const [tab, setTab] = useState(0);
  const list = tab === 0 ? store.upcomingOrders : store.pastOrders;
  const subtitle = (o: Order) => {
    const t = VT.short(o.vehicle.type);
    if (o.status === "cancelled") return `${t} · cancelled`;
    if (["noCaptain", "disputeUpheld", "captainNoShow"].includes(o.status)) return `${t} · ${Fmt.rupees(o.price)} refunded`;
    if (["approved", "autoApproved", "disputeRejected"].includes(o.status)) return `${t} · ${Fmt.rupees(o.price)} paid`;
    return `${t} · ${Fmt.rupees(o.price)} held`;
  };
  return (
    <div className="wh-fill" style={{ background: C.canvas, paddingTop: "var(--sat)" }}>
      <TD k="screen" style={{ padding: `20px ${S.gutter}px 0` }}>Bookings</TD>
      <div style={{ padding: `14px ${S.gutter}px 0` }}><Tabs options={["Upcoming", "Past"]} selection={tab} onChange={setTab} /></div>
      {list.length === 0 ? (
        <div style={{ flex: 1, display: "flex", padding: `0 ${S.gutter}px` }}>
          <FullState icon="calendar" title={tab === 0 ? "Nothing booked" : "No past washes"}
            message="Your wheels are waiting. Book a wash and we’ll find a captain nearby."
            primary="Book a wash" onPrimary={() => { store.startNewBooking(); router.push({ n: "vehicleType" }); }} />
        </div>
      ) : (
        <div className="wh-scroll" style={{ flex: 1 }}>
          <VStack gap={14} style={{ padding: `18px ${S.gutter}px` }}>
            {list.map((o) => (
              <Tap key={o.id} onClick={() => { store.currentOrderId = o.id; router.push(Status.isUpcoming(o.status) ? { n: "live" } : { n: "bookingDetail", id: o.id }); }}
                style={{ ...outlined(16, 16), display: "flex", flexDirection: "column", gap: 12, textAlign: "left" }}>
                <HStack>
                  <T k="label" c={C.heading}>{Status.isUpcoming(o.status) ? `${Slot.day(o.slot)} · ${Slot.label(o.slot)}` : Fmt.date(o.slot.date)}</T>
                  <div style={{ flex: 1 }} />
                  <StatusBadge status={o.status} />
                </HStack>
                <HStack gap={14}>
                  <IconBox icon={VT.icon(o.vehicle.type)} size={40} radius={10} />
                  <VStack gap={1} style={{ flex: 1 }}>
                    <TD k="title" w={400} s={16.5}>{o.vehicle.plate}</TD>
                    <TD k="caption">{subtitle(o)}</TD>
                  </VStack>
                  <Icon name="chevron" size={15} color={C.secondary} />
                </HStack>
              </Tap>
            ))}
          </VStack>
        </div>
      )}
    </div>
  );
}

// MARK: C44 Booking detail

export function BookingDetailScreen({ orderId }: { orderId: string }) {
  const { store, router } = useApp();
  const o = store.order(orderId);
  if (!o) return null;
  const until = Ord.reportUntil(o) ?? new Date();
  return (
    <Screen
      header={<AppBar title={Fmt.date(o.slot.date)} subtitle={`Booking #${o.ref}`} onLeading={() => router.pop()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "4px 14px 0" }} />}
      footer={<FooterBar onCall={callSupport}><Button title="Book again" icon="refresh" onClick={() => router.push({ n: "repeatBooking", id: o.id })} /></FooterBar>}
    >
      <HStack gap={8} style={{ paddingTop: 14 }}>
        <StatusBadge status={o.status} />
        {o.status === "approved" && <Badge text={`${Fmt.rupees(o.price)} paid`} tone="ok" icon="check" />}
      </HStack>
      {o.status !== "cancelled" && (
        <>
          <TD k="label" style={{ paddingTop: 20, paddingBottom: 8 }}>Photos</TD>
          <HStack gap={8}>
            {[0, 1, 2, 3].map((i) => (
              <PhotoPlaceholder key={i} height={70} icon={i % 2 === 0 ? "car" : "sparkle"} tag={i % 2 === 0 ? "Before" : "After"} tagTone={i % 2 === 0 ? "mute" : "ok"} />
            ))}
          </HStack>
        </>
      )}
      <div style={{ paddingTop: 20 }}>
        <KeyValueCard rows={[
          ["Vehicle", o.vehicle.plate],
          ["Captain", o.captain ? `${o.captain.name}${o.rating != null ? ` · you rated ${o.rating}` : ""}` : "—"],
          ["Time", `${Fmt.time(o.startedAt ?? Slot.start(o.slot))} – ${Fmt.time(o.finishedAt ?? Slot.start(o.slot))}`],
          [o.refund ? "Refunded" : "Paid", `${Fmt.rupees(o.price)} · ${o.paidWith?.title ?? "UPI"}`],
        ]} />
      </div>
      <VStack style={{ paddingTop: 16 }}>
        <ListRow icon="receipt" title="Download receipt" />
        <Divider />
        {o.refund
          ? <ListRow icon="rupee" title="Track refund" onClick={() => router.push({ n: "refund" })} />
          : <ListRow icon="flag" title="Report a problem" subtitle={`Until ${Fmt.time(until)}, ${Fmt.date(until)}`} onClick={() => router.push({ n: "reportProblem" })} />}
      </VStack>
    </Screen>
  );
}

// MARK: C45 Book again

export function RepeatScreen({ id }: { id: string }) {
  const { store, router } = useApp();
  const from = store.order(id);
  const v0 = from?.vehicle ?? store.vehicles.find((v) => v.id === id) ?? sampleCar();
  const v = { ...v0, place: from?.place ?? v0.place };
  const lastNote = store.orders.find((o) => o.vehicle.id === v.id && !Note.isEmpty(o.note))?.note ?? { ...emptyNote(), voiceSeconds: 12 };
  return (
    <Screen
      header={<AppBar title="Book again" onLeading={() => router.pop()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "4px 14px 0" }} />}
      footer={<FooterBar showCall={false}><Button title="Take photos" onClick={() => {
        store.startRepeat(v, v.place, from?.wash ?? null);
        store.draft.note = { ...lastNote };
        router.push({ n: "photos" });
      }} /></FooterBar>}
    >
      <TitleBlock title="Same wash, new time" subtitle="We kept your vehicle and parking details." top={14} />
      <HStack gap={14} style={card(16, 16)}>
        <IconBox icon={VT.icon(v.type)} size={48} radius={12} />
        <VStack gap={6} align="start">
          <Plate text={v.plate} />
          <TD k="caption">{`${VT.short(v.type)} · ${v.place?.tower ?? ""} · ${v.place ? PlaceFmt.parkingShort(v.place) : ""}`}</TD>
        </VStack>
      </HStack>
      <div style={{ paddingTop: 16 }}>
        <KeyValueCard rows={[
          ["Wash", Wash.name(from ? Ord.washKind(from) : "wetOutside", v.type.kind === "bike")],
          ["Place", v.place ? PlaceFmt.title(v.place) : ""],
          ["Parking", `${v.place?.tower ?? ""} · ${v.place ? PlaceFmt.parkingShort(v.place) : ""}`],
          ["Notes", Note.summary(lastNote)],
        ]} />
      </div>
      <TD k="label" style={{ paddingTop: 22, paddingBottom: 4 }}>Still needed for this wash</TD>
      <ListRow icon="camera" title="4 fresh photos" subtitle="Every wash starts with new photos" />
      <Divider />
      <ListRow icon="door" title="Gate pass" subtitle="We’ll ask on WhatsApp after you pay" trailing="Later" chevron={false} />
    </Screen>
  );
}

// MARK: C46 Vehicles

export function VehiclesTab() {
  const { store, router } = useApp();
  return (
    <TabScroll>
      <VStack gap={12}>
        <TD k="screen" style={{ paddingTop: 20 }}>Your vehicles</TD>
        <TD k="caption" style={{ paddingBottom: 6 }}>{`${store.myVehicles.length} saved · tap one to book`}</TD>
        {store.myVehicles.map((v) => (
          <Tap key={v.id} onClick={() => router.push({ n: "repeatBooking", id: v.id })} style={{ ...card(16, 16), display: "flex", alignItems: "center", gap: 14, textAlign: "left" }}>
            <IconBox icon={VT.icon(v.type)} size={48} radius={12} />
            <VStack gap={6} align="start" style={{ flex: 1 }}>
              <Plate text={v.plate} />
              <TD k="caption">{`${VT.short(v.type)} · ${v.place?.tower ?? ""} · ${v.place ? PlaceFmt.parkingShort(v.place) : ""}`}</TD>
            </VStack>
            <Icon name="chevron" size={15} color={C.secondary} />
          </Tap>
        ))}
        <Tap onClick={() => { store.startNewBooking(); router.push({ n: "vehicleType" }); }}
          style={{ height: 62, borderRadius: 12, border: `1px dashed ${C.dashed}`, display: "flex", alignItems: "center", justifyContent: "center", gap: 10 }}>
          <Icon name="plus" size={17} color={C.primaryStrong} weight={600} />
          <T k="title" c={C.primaryStrong}>Add a vehicle</T>
        </Tap>
      </VStack>
    </TabScroll>
  );
}

// MARK: C47 Profile (C53 delete account)

export function ProfileTab() {
  const { store, router } = useApp();
  const [showDelete, setShowDelete] = useState(false);
  const [deleteBlocked, setDeleteBlocked] = useState(false);
  const [editName, setEditName] = useState(false);
  const [newName, setNewName] = useState("");
  const c = store.customer;

  const notificationSummary = (() => {
    if (!store.notificationsOn) return "Off";
    if (store.systemPermission === "denied") return "Blocked in browser settings";
    if (isMuted(store.notificationPrefs) && store.notificationPrefs.mutedUntil) return `Muted until ${Fmt.time(store.notificationPrefs.mutedUntil)}`;
    return store.notificationPrefs.style === "bannerOnly" ? "On, no sound" : "On";
  })();

  return (
    <>
      <TabScroll>
        <VStack gap={14}>
          {c ? (
            <>
              <HStack gap={14} style={{ paddingTop: 20 }}>
                <ProfilePhotoPicker initials={Cust.initials(c)} />
                <VStack gap={1}>
                  <TD k="section" w={600}>{c.name || "Your profile"}</TD>
                  <TD k="caption">{Fmt.phone(c.phone)}</TD>
                </VStack>
              </HStack>
              {c.freeWashes > 0 && (
                <HStack gap={10} style={{ padding: "0 16px", height: 44, borderRadius: 12, background: C.successTint }}>
                  <Icon name="gift" size={16} color={C.onSuccess} />
                  <T k="caption" c={C.onSuccess} w={500}>{`${c.freeWashes} free washes left`}</T>
                </HStack>
              )}
              <VStack style={card(14, 16)}>
                <ListRow icon="edit" title="Edit name" onClick={() => { setNewName(c.name); setEditName(true); }} />
                <Divider inset={54} />
                <ListRow icon="phone" title="Phone number" subtitle={Fmt.phone(c.phone)} onClick={() => router.push({ n: "changePhone" })} />
                <Divider inset={54} />
                {c.refundUPI && (
                  <>
                    {/* Only appears once we've needed a refund UPI ID. */}
                    <ListRow icon="rupee" title="Refund UPI ID" subtitle={c.refundUPI} onClick={() => router.push({ n: "refundUPI", id: null })} />
                    <Divider inset={54} />
                  </>
                )}
                <ListRow icon="home" title="Saved places" subtitle="My Home Avatar, Tower 3" />
                <Divider inset={54} />
                <ListRow icon="bell" title="Notifications" subtitle={notificationSummary} onClick={() => router.push({ n: "notificationSettings" })} />
              </VStack>
            </>
          ) : (
            <>
              <TD k="screen" style={{ paddingTop: 20 }}>Profile</TD>
              <VStack gap={14} style={card(18)}>
                <TD k="body">Log in to see your bookings and free washes.</TD>
                <Button title="Log in" onClick={() => router.push({ n: "login" })} />
              </VStack>
            </>
          )}
          <VStack style={card(14, 16)}>
            <ListRow icon="help" title="Help and support" onClick={() => router.push({ n: "help" })} />
            <Divider inset={54} />
            <ListRow icon="doc" title="Terms and privacy" />
          </VStack>
          {c && (
            <VStack style={card(14, 16)}>
              <ListRow icon="logout" title="Log out" onClick={() => { store.signOut(); store.hasSeenWelcome = true; router.tab = 0; }} />
              <Divider inset={54} />
              <ListRow icon="trash" title="Delete account" tone="error" onClick={() => setShowDelete(true)} />
            </VStack>
          )}
        </VStack>
      </TabScroll>
      {showDelete && (
        <div className="wh-overlay wh-alert-wrap" style={{ zIndex: 30 }}>
          <div className="wh-scrim" onClick={() => setShowDelete(false)} />
          <VStack gap={12} className="wh-slide-up" style={{ position: "relative", margin: `0 ${S.gutter}px`, padding: 24, borderRadius: 28, background: "#fff" }}>
            <IconBox icon="trash" size={52} tone="error" radius={26} />
            <TD k="section" w={600}>Delete your account?</TD>
            <TD k="body">{deleteBlocked ? "You can’t do this while a wash is in progress. Try again after it’s approved."
              : `Your vehicles, bookings and ${c?.freeWashes ?? 0} free washes go with it. You can’t do this while a wash is in progress.`}</TD>
            <Button title="Delete account" kind="danger" enabled={!deleteBlocked} style={{ marginTop: 6 }} onClick={async () => {
              const ok = await store.deleteAccount().catch(() => false);
              if (ok) { setShowDelete(false); router.tab = 0; } else setDeleteBlocked(true);
            }} />
            <Button title="Keep my account" kind="text" onClick={() => { setShowDelete(false); setDeleteBlocked(false); }} />
          </VStack>
        </div>
      )}
      <Alert open={editName} title="Edit name" onClose={() => setEditName(false)}
        field={{ value: newName, onChange: setNewName, placeholder: "Your name" }}
        buttons={[{ title: "Cancel", role: "cancel" }, { title: "Save", action: () => { store.updateName(newName).catch(() => {}); } }]} />
    </>
  );
}

// MARK: C50 Offline · C51 Server error · C54 Session expired

export function OfflineScreen() {
  const { store, router } = useApp();
  return (
    <Screen scrolls={false} header={<BookingHeader step={3} label="Place" fraction={0.6} />}>
      <FullState icon="wifiOff" tone="mute" title="You’re offline" message="Check your internet. Anything you entered is saved on this phone."
        primary="Retry" onPrimary={() => { store.demo.offline = false; router.pop(); }} />
    </Screen>
  );
}

export function ServerErrorScreen() {
  const { router } = useApp();
  return (
    <Screen scrolls={false} header={<PlainHeader />}>
      <FullState icon="warning" tone="error" title="Something went wrong on our side" message="It’s not you. Try again in a minute, or call us and we’ll sort it out."
        primary="Try again" secondary="Call support" onPrimary={() => router.pop()} onSecondary={callSupport} />
    </Screen>
  );
}

export function SessionExpiredScreen() {
  const { store, router } = useApp();
  return (
    <Screen scrolls={false} header={<div style={{ height: 56 }} />}>
      <FullState icon="lock" title="Please log in again" message="For your safety we log you out after 30 days. Your bookings are safe."
        primary="Log in" onPrimary={() => { store.signOut(); router.replace([{ n: "login" }]); }} />
    </Screen>
  );
}

