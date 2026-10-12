"use client";

import { useEffect, useRef, useState } from "react";
import { Brand, C } from "../../ds/tokens";
import {
  ActionSheet, Alert, AppBar, Banner, Button, Chip, Divider, FullState, HStack, IconBox, Link, Radio, Screen, StateCircle, Tap, T, TD,
  ToggleRow, VStack, card,
} from "../../ds/components";
import { Icon } from "../../ds/icons";
import { Fmt, isToday, isYesterday } from "../../lib/fmt";
import { useApp, useOnAppear } from "../ctx";
import {
  alertStyleTitle, Cat, isMuted, Kind, NotificationCategories, openNotification, type AlertStyle, type AppNotification, type NotificationCategory,
} from "../store";

const relative = (d: Date) => {
  const s = (Date.now() - d.getTime()) / 1000;
  if (s < 60) return "Now";
  if (s < 3600) return `${Math.floor(s / 60)} min`;
  if (isToday(d)) return `${Math.floor(s / 3600)} h`;
  if (isYesterday(d)) return Fmt.time(d);
  return Fmt.date(d);
};

// MARK: Notification centre (bell on Home)

export function NotificationsScreen() {
  const { store, router } = useApp();
  const [filter, setFilter] = useState<NotificationCategory | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [confirmClear, setConfirmClear] = useState(false);
  const [menu, setMenu] = useState<AppNotification | null>(null);
  const items = store.notifications.filter((n) => filter == null || Kind.category(n.kind) === filter);
  const sections = ([["Today", items.filter((n) => isToday(n.date))], ["Yesterday", items.filter((n) => isYesterday(n.date))],
    ["Earlier", items.filter((n) => !isToday(n.date) && !isYesterday(n.date))]] as [string, AppNotification[]][]).filter(([, l]) => l.length);
  const prefs = store.notificationPrefs;

  const row = (n: AppNotification) => {
    const expired = !!n.expiresAt && n.expiresAt.getTime() < Date.now();
    return (
      <Tap key={n.id} className="wh-nopress wh-row" onClick={() => { const m = openNotification(n, store, router); if (m) setInfo(m); }} onContext={() => setMenu(n)}
        label={`${n.read ? "" : "Unread. "}${n.title}. ${n.body}`}
        style={{ display: "flex", alignItems: "flex-start", gap: 12, padding: 14, width: "100%", textAlign: "left", background: n.read ? "transparent" : "rgba(234,240,255,.35)" }}>
        <IconBox icon={Kind.icon(n.kind)} size={38} tone={expired ? "mute" : Kind.tone(n.kind)} radius={10} />
        <VStack gap={3} style={{ flex: 1, minWidth: 0 }}>
          <HStack align="baseline" gap={6}>
            <TD k="title" w={n.read ? 400 : 600} s={15.5} style={{ flex: 1 }}>{n.title}</TD>
            <T k="small" c={C.muted}>{relative(n.date)}</T>
          </HStack>
          <TD k="caption" lines={3}>{n.body}</TD>
          {expired && <TD k="small" c={C.muted} style={{ paddingTop: 2 }}>Offer ended</TD>}
        </VStack>
        <span style={{ width: 8, height: 8, borderRadius: 4, marginTop: 6, background: n.read ? "transparent" : C.primary, flexShrink: 0 }} />
      </Tap>
    );
  };

  return (
    <Screen canvas header={<AppBar title="Notifications" trailing={store.customer ? "gear" : null} onLeading={() => router.pop()} onTrailing={() => router.push({ n: "notificationSettings" })} style={{ padding: "4px 14px 0" }} />}>
      {!store.customer ? (
        <div style={{ paddingTop: 40 }}>
          <FullState icon="bell" title="Log in to see your updates" message="Booking updates, refunds and offers show up here once you’re logged in."
            primary="Log in" onPrimary={() => router.push({ n: "login" })} />
        </div>
      ) : (
        <>
          {/* Why updates might not reach the customer, with the fix one tap away. */}
          {!store.notificationsOn ? (
            <Banner tone="wait" icon="bellSlash" title="Notifications are off." text="Updates still land here, but we won’t alert you." actionTitle="Turn on" onAction={() => store.setNotifications(true)} style={{ marginTop: 10 }} />
          ) : store.systemPermission === "denied" ? (
            <Banner tone="error" icon="bellSlash" title="Blocked in browser settings." text={`Allow notifications for ${Brand.name} in your browser’s site settings to get alerts.`} style={{ marginTop: 10 }} />
          ) : isMuted(prefs) && prefs.mutedUntil ? (
            <Banner tone="info" icon="speakerOff" title={`Muted until ${Fmt.day(prefs.mutedUntil)}, ${Fmt.time(prefs.mutedUntil)}.`} text="Updates land here quietly." actionTitle="Unmute" onAction={() => store.mute(null)} style={{ marginTop: 10 }} />
          ) : null}
          <div className="wh-scroll" style={{ overflowX: "auto", overflowY: "hidden", margin: "6px -26px 4px", padding: "2px 26px" }}>
            <HStack gap={8}>
              <Chip title="All" selected={filter == null} height={36} onClick={() => setFilter(null)} />
              {NotificationCategories.map((c) => <Chip key={c} title={Cat.filter(c)} selected={filter === c} height={36} onClick={() => setFilter(c)} />)}
            </HStack>
          </div>
          {items.length === 0 ? (
            <VStack gap={12} align="center" style={{ paddingTop: 50 }}>
              <StateCircle icon="bell" size={72} />
              <TD k="section" w={600}>{filter == null ? "No notifications yet" : "Nothing here"}</TD>
              <TD k="body" center>{filter == null ? "We’ll let you know when a captain accepts, when photos are ready and when money moves." : `No ${Cat.filter(filter).toLowerCase()} updates right now.`}</TD>
            </VStack>
          ) : (
            <>
              <HStack style={{ paddingTop: 10 }}>
                <T k="label" style={{ flex: 1 }}>{store.unreadCount === 0 ? "All caught up" : `${store.unreadCount} unread`}</T>
                {store.unreadCount > 0 && <Link title="Mark all as read" k="caption" onClick={() => store.markAllRead()} />}
              </HStack>
              {sections.map(([title, list]) => (
                <div key={title}>
                  <TD k="label" c={C.muted} style={{ paddingTop: 16, paddingBottom: 8 }}>{title}</TD>
                  <div style={{ ...card(0, 16), overflow: "hidden" }}>
                    {list.map((n, i) => (
                      <div key={n.id}>{row(n)}{i < list.length - 1 && <Divider inset={62} />}</div>
                    ))}
                  </div>
                </div>
              ))}
              <Button title="Clear all" kind="text" onClick={() => setConfirmClear(true)} style={{ marginTop: 16 }} />
              <TD k="small" c={C.muted} center style={{ paddingTop: 2 }}>Long-press a notification to delete it or mark it unread.</TD>
            </>
          )}
        </>
      )}
      <Alert open={info != null} title={info ?? ""} onClose={() => setInfo(null)} />
      <ActionSheet open={confirmClear} onClose={() => setConfirmClear(false)} title="Clear all notifications?" message="This only clears the list. Your bookings aren’t affected."
        actions={[{ title: "Clear all", role: "destructive", action: () => store.clearNotifications() }]} />
      <ActionSheet open={menu != null} onClose={() => setMenu(null)} title={menu?.title}
        actions={menu ? [
          menu.read ? { title: "Mark as unread", action: () => store.markUnread(menu.id) } : { title: "Mark as read", action: () => store.markRead(menu.id) },
          { title: "Delete", role: "destructive", action: () => store.deleteNotification(menu.id) },
        ] : []} />
    </Screen>
  );
}

// MARK: Notification settings (Profile → Notifications, or the gear)

export function NotificationSettingsScreen() {
  const { store, router } = useApp();
  const [confirmBookingsOff, setConfirmBookingsOff] = useState(false);
  useOnAppear(() => store.refreshSystemPermission());
  const on = store.notificationsOn;
  const prefs = store.notificationPrefs;
  const styles: AlertStyle[] = ["soundAndBanner", "bannerOnly"];
  return (
    <Screen canvas header={<AppBar title="Notifications" trailing={null} onLeading={() => router.pop()} style={{ padding: "4px 14px 0" }} />}>
      <div style={{ ...card(16, 16), marginTop: 14 }}>
        <ToggleRow on={on} onChange={(v) => store.setNotifications(v)}>
          <TD k="title">Allow notifications</TD>
          <TD k="caption">{on ? "We’ll alert you about your washes." : "Off. Updates still show in the list."}</TD>
        </ToggleRow>
      </div>
      {store.systemPermission === "denied" && on && (
        <Banner tone="error" icon="bellSlash" title="Blocked in browser settings." text={`We can’t alert you until you allow notifications for ${Brand.name}.`} style={{ marginTop: 12 }} />
      )}
      <div style={{ opacity: on ? 1 : 0.45, pointerEvents: on ? "auto" : "none", display: "flex", flexDirection: "column" }}>
        <TD k="label" style={{ paddingTop: 24, paddingBottom: 8 }}>How they arrive</TD>
        <div style={card(14, 16)}>
          {styles.map((s, i) => (
            <div key={s}>
              <Tap className="wh-nopress" onClick={() => { store.notificationPrefs.style = s; }} style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 0", width: "100%" }}>
                <span style={{ width: 24, display: "grid", placeItems: "center" }}><Icon name={s === "soundAndBanner" ? "bell" : "speakerOff"} size={17} color={C.primaryStrong} /></span>
                <TD k="rowTitle" style={{ flex: 1, textAlign: "left" }}>{alertStyleTitle(s)}</TD>
                <Radio on={prefs.style === s} />
              </Tap>
              {i < styles.length - 1 && <Divider inset={36} />}
            </div>
          ))}
        </div>
        <TD k="label" style={{ paddingTop: 24, paddingBottom: 8 }}>Mute for a while</TD>
        <VStack gap={12} style={card(16, 16)}>
          {isMuted(prefs) && prefs.mutedUntil ? (
            <HStack gap={8}>
              <Icon name="speakerOff" size={16} color={C.primaryStrong} />
              <T k="bodyStrong" style={{ flex: 1 }}>{`Muted until ${Fmt.day(prefs.mutedUntil)}, ${Fmt.time(prefs.mutedUntil)}`}</T>
              <Link title="Unmute" k="caption" onClick={() => store.mute(null)} />
            </HStack>
          ) : <TD k="caption">No banners or sounds. Everything still lands in the list.</TD>}
          <HStack gap={8}>
            <Chip title="1 hour" height={38} onClick={() => store.mute(3600)} />
            <Chip title="8 hours" height={38} onClick={() => store.mute(8 * 3600)} />
            <Chip title="Till morning" height={38} onClick={() => store.muteUntilMorning()} />
          </HStack>
        </VStack>
        <div style={{ ...card(16, 16), marginTop: 12 }}>
          <ToggleRow on={prefs.quietHours} onChange={(v) => { store.notificationPrefs.quietHours = v; }}>
            <TD k="title">Quiet hours</TD>
            <TD k="caption">10 PM – 7 AM: banners arrive without sound.</TD>
          </ToggleRow>
        </div>
        <TD k="label" style={{ paddingTop: 24, paddingBottom: 8 }}>What you hear about</TD>
        <div style={card(16, 16)}>
          {NotificationCategories.map((c, i) => (
            <div key={c}>
              <ToggleRow on={c === "account" || prefs.categories.includes(c)} disabled={c === "account"} style={{ padding: "10px 0" }}
                onChange={(v) => {
                  if (c === "bookings" && !v) { setConfirmBookingsOff(true); return; }
                  store.notificationPrefs.categories = v ? [...prefs.categories, c] : prefs.categories.filter((x) => x !== c);
                }}>
                <TD k="rowTitle">{Cat.title(c)}</TD>
                <TD k="caption">{Cat.detail(c)}</TD>
              </ToggleRow>
              {i < NotificationCategories.length - 1 && <Divider />}
            </div>
          ))}
        </div>
      </div>
      <TD k="small" c={C.muted} style={{ paddingTop: 14 }}>Turning things off here never cancels a booking. Photo checks still auto-approve at midnight.</TD>
      <Alert open={confirmBookingsOff} onClose={() => setConfirmBookingsOff(false)} title="Turn off booking updates?"
        message="You might miss when the captain arrives or when photos are ready. If you don’t check them, the wash auto-approves at midnight."
        buttons={[{ title: "Keep them on", role: "cancel" }, { title: "Turn off", role: "destructive", action: () => { store.notificationPrefs.categories = prefs.categories.filter((x) => x !== "bookings"); } }]} />
    </Screen>
  );
}

// MARK: In-app banner and toast (shown over every screen)

export function LiveNotificationBanner() {
  const { store, router } = useApp();
  const [info, setInfo] = useState<string | null>(null);
  const n = store.liveBanner;
  const t = store.toast;
  const start = useRef<number | null>(null);

  useEffect(() => {
    if (!n) return;
    const id = n.id;
    const h = setTimeout(() => { if (store.liveBanner?.id === id) store.liveBanner = null; }, 4500);
    return () => clearTimeout(h);
  }, [n, store]);

  useEffect(() => {
    if (!t) return;
    const h = setTimeout(() => { if (store.toast === t) store.toast = null; }, 3000);
    return () => clearTimeout(h);
  }, [t, store]);

  return (
    <>
      {n && (
        <div key={n.id} className="wh-banner-in" style={{ position: "absolute", top: "calc(var(--sat) + 4px)", left: 12, right: 12, zIndex: 60 }}
          onPointerDown={(e) => { start.current = e.clientY; }}
          onPointerUp={(e) => { if (start.current != null && e.clientY - start.current < -10) store.liveBanner = null; start.current = null; }}>
          <Tap onClick={() => { const m = openNotification(n, store, router); if (m) setInfo(m); }}
            style={{ display: "flex", alignItems: "flex-start", gap: 12, padding: 14, width: "100%", textAlign: "left", background: "#fff", borderRadius: 18, boxShadow: `0 6px 16px ${C.shadow}` }}>
            <IconBox icon={Kind.icon(n.kind)} size={36} tone={Kind.tone(n.kind)} radius={10} />
            <VStack gap={2} style={{ flex: 1, minWidth: 0 }}>
              <TD k="title" s={15}>{n.title}</TD>
              <TD k="caption" lines={2}>{n.body}</TD>
            </VStack>
          </Tap>
        </div>
      )}
      {t && (
        <div key={t} className="wh-slide-up" style={{ position: "absolute", left: 0, right: 0, bottom: "calc(100px + var(--sab))", display: "flex", justifyContent: "center", zIndex: 60, pointerEvents: "none" }}>
          <span style={{ padding: "12px 16px", borderRadius: 999, background: C.inverse, maxWidth: "86%" }}><T k="caption" c="#fff" w={500}>{t}</T></span>
        </div>
      )}
      <Alert open={info != null} title={info ?? ""} onClose={() => setInfo(null)} />
    </>
  );
}
