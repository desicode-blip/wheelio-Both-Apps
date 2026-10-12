"use client";

// Wheelio components, ported from apps/ios/Shared/DesignSystem (Buttons, Inputs, Layout, Display).
// One primary action per screen. Green only to pay, approve or accept. Red only for errors and
// destructive actions. Colour is never the only signal: always pair a tone with an icon and a word.

import { createContext, useContext, useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { C, R, S, TYPE, toneBanner, toneBg, toneFg, type Tone, type TypeKey } from "./tokens";
import { Icon, type IconName } from "./icons";
import { Validators } from "../lib/fmt";

type Style = CSSProperties;

/** The full-phone layer that sheets, alerts and menus render into. */
export const OverlayHost = createContext<HTMLElement | null>(null);

function Portal({ children }: { children: ReactNode }) {
  const host = useContext(OverlayHost);
  return host ? createPortal(children, host) : <>{children}</>;
}

/** Text scale for the 200% text screen (C52). */
export const TextScale = createContext(1);

// MARK: - Text

export function T({ k, c, w, s, children, style, lines, center, under, strike, mono, tracking, as = "span" }: {
  k: TypeKey; c?: string; w?: number; s?: number; children?: ReactNode; style?: Style; lines?: number; center?: boolean;
  under?: boolean; strike?: boolean; mono?: boolean; tracking?: number; as?: "span" | "div";
}) {
  const scale = useContext(TextScale);
  const t = TYPE[k];
  const size = (s ?? t.size) * scale;
  const Tag = as;
  return (
    <Tag
      style={{
        display: as === "div" ? "block" : undefined,
        fontSize: size,
        lineHeight: `${(t.line / t.size) * size}px`,
        fontWeight: w ?? t.weight,
        color: c ?? t.color,
        textAlign: center ? "center" : undefined,
        textDecoration: under ? "underline" : strike ? "line-through" : undefined,
        textDecorationColor: strike ? C.muted : undefined,
        fontVariantNumeric: mono ? "tabular-nums" : undefined,
        letterSpacing: tracking,
        whiteSpace: "pre-line",
        ...(lines ? { display: "-webkit-box", WebkitLineClamp: lines, WebkitBoxOrient: "vertical", overflow: "hidden" } : null),
        ...style,
      }}
    >
      {children}
    </Tag>
  );
}

/** Text block (div) shorthand. */
export const TD = (p: Parameters<typeof T>[0]) => <T {...p} as="div" />;

export const B = ({ children, w = 700 }: { children: ReactNode; w?: number }) => <span style={{ fontWeight: w }}>{children}</span>;

// MARK: - Layout helpers

export const VStack = ({ gap = 0, align = "stretch", children, style, ...rest }: {
  gap?: number; align?: "start" | "center" | "end" | "stretch"; children?: ReactNode; style?: Style;
} & React.HTMLAttributes<HTMLDivElement>) => (
  <div {...rest} style={{ display: "flex", flexDirection: "column", gap, alignItems: align === "start" ? "flex-start" : align === "end" ? "flex-end" : align, ...style }}>
    {children}
  </div>
);

export const HStack = ({ gap = 0, align = "center", children, style, ...rest }: {
  gap?: number; align?: "start" | "center" | "end" | "stretch" | "baseline"; children?: ReactNode; style?: Style;
} & React.HTMLAttributes<HTMLDivElement>) => (
  <div {...rest} style={{ display: "flex", flexDirection: "row", gap, alignItems: align === "start" ? "flex-start" : align === "end" ? "flex-end" : align, ...style }}>
    {children}
  </div>
);

export const Spacer = ({ min = 0 }: { min?: number }) => <div style={{ flex: 1, minWidth: min, minHeight: min }} />;

/** Elevation/Card on canvas: white, radius 20. */
export const card = (padding = 16, radius: number = R.card): Style => ({
  padding, width: "100%", background: C.white, borderRadius: radius, boxShadow: `0 4px 10px ${C.shadowCard}`, boxSizing: "border-box",
});

/** Outlined card (border/default). */
export const outlined = (padding = 16, radius: number = R.card, fill: string = C.white, stroke: string = C.border, lw = 1): Style => ({
  padding, width: "100%", background: fill, borderRadius: radius, boxShadow: `inset 0 0 0 ${lw}px ${stroke}`, boxSizing: "border-box",
});

/** Plain tappable surface with the subtle press feedback. */
export function Tap({ onClick, children, style, disabled, label, className = "", onContext }: {
  onClick?: () => void; children: ReactNode; style?: Style; disabled?: boolean; label?: string; className?: string;
  onContext?: () => void;
}) {
  const lp = useLongPress(onContext);
  return (
    <button
      type="button"
      aria-label={label}
      disabled={disabled}
      className={`wh-tap wh-press ${className}`}
      onClick={(e) => {
        if (lp.fired()) return;
        e.stopPropagation();
        onClick?.();
      }}
      {...(onContext ? lp.handlers : {})}
      style={style}
    >
      {children}
    </button>
  );
}

/** Long-press (or right-click) for context menus. */
export function useLongPress(cb?: () => void) {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const firedRef = useRef(false);
  const clear = () => { if (timer.current) clearTimeout(timer.current); timer.current = null; };
  return {
    fired: () => { const f = firedRef.current; firedRef.current = false; return f; },
    handlers: {
      onPointerDown: () => { firedRef.current = false; clear(); timer.current = setTimeout(() => { firedRef.current = true; cb?.(); }, 520); },
      onPointerUp: clear,
      onPointerLeave: clear,
      onPointerCancel: clear,
      onContextMenu: (e: React.MouseEvent) => { e.preventDefault(); clear(); firedRef.current = false; cb?.(); },
    },
  };
}

// MARK: - Buttons

export type ButtonKind = "primary" | "success" | "outline" | "text" | "danger" | "tonal";
export type ButtonSize = "regular" | "captain" | "accept";

const BTN_H: Record<ButtonSize, number> = { regular: 52, captain: 64, accept: 72 };
const BTN_F: Record<ButtonSize, number> = { regular: 16.5, captain: 19, accept: 22 };

export function Button({ title, icon, kind = "primary", size = "regular", enabled = true, loading = false, fullWidth = true, onClick, style }: {
  title: string; icon?: IconName; kind?: ButtonKind; size?: ButtonSize; enabled?: boolean; loading?: boolean;
  fullWidth?: boolean; onClick?: () => void; style?: Style;
}) {
  const bg = !enabled ? (kind === "text" ? "transparent" : C.disabled)
    : { primary: C.primary, success: C.success, outline: C.white, text: "transparent", danger: C.destructive, tonal: C.primaryTint }[kind];
  const fg = !enabled ? C.placeholder
    : { primary: C.white, danger: C.white, success: C.onSuccess, outline: C.primaryStrong, text: C.primaryStrong, tonal: C.primaryStrong }[kind];
  const fs = BTN_F[size];
  return (
    <button
      type="button"
      className="wh-tap wh-press"
      disabled={!enabled}
      aria-label={title}
      onClick={(e) => { e.stopPropagation(); if (enabled && !loading) onClick?.(); }}
      style={{
        display: "flex", alignItems: "center", justifyContent: "center", gap: 8, padding: "0 20px",
        width: fullWidth ? "100%" : undefined, minHeight: kind === "text" ? 48 : BTN_H[size], borderRadius: 999,
        background: bg, color: fg, flexShrink: fullWidth ? 1 : 0,
        boxShadow: kind === "outline" ? `inset 0 0 0 1.5px ${enabled ? C.primary : C.border}` : undefined,
        cursor: enabled ? "pointer" : "default", ...style,
      }}
    >
      {loading ? <Spinner color={fg} /> : (
        <>
          {icon && <Icon name={icon} size={fs + 1} color={fg} weight={500} />}
          <span style={{ fontSize: fs, fontWeight: 600, lineHeight: 1.2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{title}</span>
        </>
      )}
    </button>
  );
}

/** Icon button: elevated (Elevation/Subtle), flat, or tinted. */
export function IconButton({ icon, style = "elevated", size = 48, label, onClick }: {
  icon: IconName; style?: "elevated" | "flat" | "tint"; size?: number; label?: string; onClick?: () => void;
}) {
  return (
    <Tap
      onClick={onClick}
      label={label ?? icon}
      style={{
        width: size, height: size, borderRadius: "50%", flexShrink: 0, display: "grid", placeItems: "center",
        background: style === "elevated" ? C.white : style === "tint" ? C.primaryTint : "transparent",
        boxShadow: style === "elevated" ? `0 1px 3px ${C.shadow}` : undefined,
      }}
    >
      <Icon name={icon} size={size * 0.42} color={style === "tint" ? C.primaryStrong : C.heading} />
    </Tap>
  );
}

/** Underlined inline link, e.g. "Change", "Retry", "See tomorrow". */
export function Link({ title, color = C.primaryStrong, k = "body", onClick, style }: {
  title: string; color?: string; k?: TypeKey; onClick?: () => void; style?: Style;
}) {
  return (
    <Tap onClick={onClick} style={{ minHeight: 44, display: "flex", alignItems: "center", ...style }}>
      <T k={k} c={color} w={500} under lines={2}>{title}</T>
    </Tap>
  );
}

export function Spinner({ color = C.primary, size = 20 }: { color?: string; size?: number }) {
  return <span className="wh-spin" style={{ width: size, height: size, borderColor: color, borderTopColor: "transparent" }} />;
}

// MARK: - App bar

/** App bar: back (or close) on the left, title in the middle, help on the right. */
export function AppBar({ title = "", subtitle, leading = "left", trailing = "help", dark = false, onLeading, onTrailing, style }: {
  title?: string; subtitle?: string; leading?: IconName | null; trailing?: IconName | null; dark?: boolean;
  onLeading?: () => void; onTrailing?: () => void; style?: Style;
}) {
  const fg = dark ? C.white : C.heading;
  return (
    <HStack style={{ minHeight: 56, ...style }}>
      {leading ? (
        <Tap onClick={onLeading} label={leading === "close" ? "Close" : "Go back"} style={{ width: 48, height: 48, display: "grid", placeItems: "center" }}>
          <Icon name={leading} size={leading === "close" ? 21 : 24} color={fg} weight={500} />
        </Tap>
      ) : <div style={{ width: 48, height: 48 }} />}
      <VStack align="center" style={{ flex: 1, minWidth: 0 }}>
        {title && <T k="appBarTitle" c={fg} lines={1}>{title}</T>}
        {subtitle && <T k="caption" c={dark ? "rgba(255,255,255,.7)" : C.secondary} lines={1}>{subtitle}</T>}
      </VStack>
      {trailing ? (
        <Tap onClick={onTrailing} label={trailing === "help" ? "Get help" : trailing} style={{ width: 48, height: 48, display: "grid", placeItems: "center" }}>
          <Icon name={trailing} size={23} color={fg} />
        </Tap>
      ) : <div style={{ width: 48, height: 48 }} />}
    </HStack>
  );
}

// MARK: - Progress

/** Progress: thin track plus "Step 1 of 5 · Vehicle". */
export function Progress({ step, of, label, done = false }: { step: number; of: number; label?: string; done?: boolean }) {
  return (
    <VStack gap={6}>
      <div style={{ height: 4, borderRadius: 4, background: C.track, overflow: "hidden" }}>
        <div style={{ height: 4, borderRadius: 4, width: `${(step / Math.max(of, 1)) * 100}%`, background: done ? C.success : C.primary, transition: "width .3s" }} />
      </div>
      {label && <T k="label" c={C.primaryStrong}>{label}</T>}
    </VStack>
  );
}

/** Segmented step bar used by the captain app. */
export function SegmentBar({ filled, total, labels = [], greenUpTo = 0 }: { filled: number; total: number; labels?: string[]; greenUpTo?: number }) {
  return (
    <VStack gap={4}>
      <HStack gap={6}>
        {Array.from({ length: total }, (_, i) => (
          <div key={i} style={{ flex: 1, height: 4, borderRadius: 4, background: i < greenUpTo ? C.success : i < filled ? C.primary : C.track }} />
        ))}
      </HStack>
      {labels.length > 0 && (
        <HStack gap={6}>
          {labels.map((l, i) => (
            <T key={i} k="caption" c={i < filled ? C.heading : C.secondary} w={i < filled ? 500 : 400} style={{ flex: 1 }}>{l}</T>
          ))}
        </HStack>
      )}
    </VStack>
  );
}

// MARK: - Footer bar

/** Footer bar: call/help on the left, the screen's one primary action on the right. */
export function FooterBar({ showCall = true, captain = false, onCall, children }: {
  showCall?: boolean; captain?: boolean; onCall?: () => void; children?: ReactNode;
}) {
  return (
    <div style={{ background: C.white, borderTop: `1px solid ${C.divider}` }}>
      <HStack gap={12} style={{ padding: `12px ${captain ? S.gutterCaptain : S.gutter}px 12px` }}>
        {showCall && <IconButton icon="phone" style={captain ? "tint" : "elevated"} size={captain ? 64 : 48} label="Call support" onClick={onCall} />}
        <div style={{ flex: 1, minWidth: 0 }}>{children}</div>
      </HStack>
    </div>
  );
}

/** Footer with a primary action and a text action stacked. */
export function StackedFooter({ captain = false, children }: { captain?: boolean; children?: ReactNode }) {
  return (
    <div style={{ background: C.white, borderTop: `1px solid ${C.divider}` }}>
      <VStack gap={4} align="center" style={{ padding: `12px ${captain ? S.gutterCaptain : S.gutter}px 4px` }}>{children}</VStack>
    </div>
  );
}

// MARK: - Screen scaffold

/** A screen: optional app bar, scrolling content, footer pinned to the bottom. Handles the safe areas. */
export function Screen({ canvas = false, gutter = S.gutter, scrolls = true, header, footer, children, bg }: {
  canvas?: boolean; gutter?: number; scrolls?: boolean; header?: ReactNode; footer?: ReactNode; children?: ReactNode; bg?: string;
}) {
  const background = bg ?? (canvas ? C.canvas : C.white);
  return (
    <div className="wh-screen" style={{ background, paddingTop: "var(--sat)" }}>
      {header}
      {scrolls ? (
        <div className="wh-scroll" style={{ flex: 1 }}>
          <div style={{ padding: `0 ${gutter}px`, paddingBottom: footer ? 24 : "calc(24px + var(--sab))", display: "flex", flexDirection: "column" }}>{children}</div>
        </div>
      ) : (
        <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: `0 ${gutter}px`, minHeight: 0, paddingBottom: footer ? 0 : "var(--sab)" }}>{children}</div>
      )}
      {footer && <div style={{ background: C.white, paddingBottom: "var(--sab)" }}>{footer}</div>}
    </div>
  );
}

/** Title block: Heading/Screen plus optional subtitle. */
export function TitleBlock({ title, subtitle, top = 20 }: { title: string; subtitle?: string | null; top?: number }) {
  return (
    <VStack gap={6} style={{ paddingTop: top, paddingBottom: 20 }}>
      <TD k="screen">{title}</TD>
      {subtitle ? <TD k="body">{subtitle}</TD> : null}
    </VStack>
  );
}

export const SectionLabel = ({ text, style }: { text: string; style?: Style }) => <TD k="label" style={{ paddingBottom: 8, ...style }}>{text}</TD>;

// MARK: - Bottom navigation

export type NavItem = { id: number; title: string; icon: IconName; badge?: number };

export function BottomNav({ items, selection, onSelect }: { items: NavItem[]; selection: number; onSelect: (id: number) => void }) {
  return (
    <div style={{ background: C.white, borderTop: `1px solid ${C.divider}`, paddingBottom: "var(--sab)" }}>
      <HStack>
        {items.map((it) => {
          const on = selection === it.id;
          return (
            <Tap key={it.id} onClick={() => onSelect(it.id)} label={it.title} className="wh-nopress"
              style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 4, padding: "8px 0 4px" }}>
              <div style={{ position: "relative", width: 56, height: 30, borderRadius: 999, background: on ? C.primaryTint : "transparent", display: "grid", placeItems: "center" }}>
                <Icon name={it.icon} size={21} color={on ? C.primaryStrong : C.secondary} weight={on ? 600 : 400} />
                {(it.badge ?? 0) > 0 && (
                  <span style={{ position: "absolute", top: -3, right: 8, width: 16, height: 16, borderRadius: 8, background: C.destructive, color: "#fff", fontSize: 10, fontWeight: 700, display: "grid", placeItems: "center" }}>{it.badge}</span>
                )}
              </div>
              <T k="label" c={on ? C.heading : C.secondary} w={on ? 600 : 400}>{it.title}</T>
            </Tap>
          );
        })}
      </HStack>
    </div>
  );
}

// MARK: - Sheets, alerts, menus

/** Bottom sheet with grab handle, sized to a height (detent). Rendered over the whole phone. */
export function Sheet({ open, onClose, height, children, gutter = S.gutter, grab = true }: {
  open: boolean; onClose: () => void; height: number; children: ReactNode; gutter?: number; grab?: boolean;
}) {
  const shown = usePresence(open, 280);
  if (!shown) return null;
  return (
    <Portal>
    <div className="wh-overlay" data-open={open}>
      <div className="wh-scrim" onClick={onClose} />
      <div className="wh-sheet" data-open={open} style={{ height: `calc(${height}px + var(--sab))`, padding: `0 ${gutter}px calc(8px + var(--sab))` }}>
        {grab && <div style={{ width: 36, height: 4, borderRadius: 4, background: C.grab, margin: "10px auto 14px" }} />}
        <div style={{ flex: 1, minHeight: 0, display: "flex", flexDirection: "column" }}>{children}</div>
      </div>
    </div>
    </Portal>
  );
}

/** Keeps an element mounted while it animates out. */
export function usePresence(open: boolean, ms: number) {
  const [shown, setShown] = useState(open);
  useEffect(() => {
    if (open) { setShown(true); return; }
    const t = setTimeout(() => setShown(false), ms);
    return () => clearTimeout(t);
  }, [open, ms]);
  return open || shown;
}

export type AlertButton = { title: string; role?: "cancel" | "destructive"; action?: () => void };

/** iOS-style alert. */
export function Alert({ open, title, message, buttons = [{ title: "OK", role: "cancel" }], onClose, field }: {
  open: boolean; title: string; message?: string; buttons?: AlertButton[]; onClose: () => void;
  field?: { value: string; onChange: (v: string) => void; placeholder?: string };
}) {
  const shown = usePresence(open, 200);
  if (!shown) return null;
  const vertical = buttons.length > 2;
  return (
    <Portal>
    <div className="wh-overlay wh-alert-wrap" data-open={open}>
      <div className="wh-scrim" style={{ background: "rgba(0,0,0,.28)" }} />
      <div className="wh-alert" role="alertdialog" aria-label={title}>
        <div style={{ padding: "19px 16px 15px", textAlign: "center" }}>
          <div style={{ fontSize: 17, fontWeight: 600, lineHeight: "22px", color: "#000" }}>{title}</div>
          {message && <div style={{ fontSize: 13, lineHeight: "17px", color: "#000", marginTop: 4 }}>{message}</div>}
          {field && (
            <input autoFocus className="wh-alert-input" value={field.value} placeholder={field.placeholder}
              onChange={(e) => field.onChange(e.target.value)} />
          )}
        </div>
        <div style={{ display: "flex", flexDirection: vertical ? "column" : "row", borderTop: "0.5px solid rgba(60,60,67,.29)" }}>
          {buttons.map((b, i) => (
            <button key={i} type="button" className="wh-tap wh-alert-btn"
              onClick={() => { onClose(); b.action?.(); }}
              style={{
                flex: 1, height: 44, fontSize: 17, color: b.role === "destructive" ? "#FF3B30" : "#007AFF", fontWeight: b.role === "cancel" ? 600 : 400,
                borderLeft: !vertical && i > 0 ? "0.5px solid rgba(60,60,67,.29)" : undefined,
                borderTop: vertical && i > 0 ? "0.5px solid rgba(60,60,67,.29)" : undefined,
              }}>{b.title}</button>
          ))}
        </div>
      </div>
    </div>
    </Portal>
  );
}

/** Action sheet (confirmationDialog and long-press context menus). */
export function ActionSheet({ open, title, message, actions, onClose, cancel = "Cancel" }: {
  open: boolean; title?: string; message?: string; actions: AlertButton[]; onClose: () => void; cancel?: string;
}) {
  const shown = usePresence(open, 250);
  if (!shown) return null;
  return (
    <Portal>
    <div className="wh-overlay" data-open={open}>
      <div className="wh-scrim" onClick={onClose} style={{ background: "rgba(0,0,0,.28)" }} />
      <div className="wh-actions" data-open={open}>
        <div style={{ background: "rgba(249,249,249,.96)", borderRadius: 14, overflow: "hidden" }}>
          {(title || message) && (
            <div style={{ padding: "14px 16px", textAlign: "center", borderBottom: "0.5px solid rgba(60,60,67,.29)" }}>
              {title && <div style={{ fontSize: 13, fontWeight: 600, color: "#8A8A8E" }}>{title}</div>}
              {message && <div style={{ fontSize: 13, color: "#8A8A8E", marginTop: 4 }}>{message}</div>}
            </div>
          )}
          {actions.map((a, i) => (
            <button key={i} type="button" className="wh-tap wh-alert-btn" onClick={() => { onClose(); a.action?.(); }}
              style={{ width: "100%", height: 57, fontSize: 20, color: a.role === "destructive" ? "#FF3B30" : "#007AFF", borderTop: i > 0 ? "0.5px solid rgba(60,60,67,.29)" : undefined }}>
              {a.title}
            </button>
          ))}
        </div>
        <button type="button" className="wh-tap wh-alert-btn" onClick={onClose}
          style={{ width: "100%", height: 57, fontSize: 20, fontWeight: 600, color: "#007AFF", background: "#fff", borderRadius: 14, marginTop: 8 }}>{cancel}</button>
      </div>
    </div>
    </Portal>
  );
}

// MARK: - Display

/** Rounded square holding an icon (tinted), used in tiles and rows. */
export function IconBox({ icon, size = 44, tone = "info", radius = 12, iconSize }: { icon: IconName; size?: number; tone?: Tone; radius?: number; iconSize?: number }) {
  return (
    <div style={{ width: size, height: size, borderRadius: radius, background: toneBg[tone], display: "grid", placeItems: "center", flexShrink: 0 }}>
      <Icon name={icon} size={iconSize ?? size * 0.45} color={toneFg[tone]} />
    </div>
  );
}

/** Large state circle with an icon, used by full-screen states. */
export function StateCircle({ icon, tone = "info", size = 96, spinning = false, pulse = false }: { icon: IconName; tone?: Tone; size?: number; spinning?: boolean; pulse?: boolean }) {
  return (
    <div className={pulse ? "wh-pulse" : undefined} style={{ width: size, height: size, borderRadius: "50%", background: toneBg[tone], display: "grid", placeItems: "center", flexShrink: 0 }}>
      {spinning ? <Spinner size={size * 0.34} /> : <Icon name={icon} size={size * 0.36} color={tone === "ok" ? C.onSuccess : toneFg[tone]} weight={500} />}
    </div>
  );
}

/** Badge: icon + word on a tint. */
export function Badge({ text, tone = "info", icon, solid = false, style }: { text: string; tone?: Tone; icon?: IconName; solid?: boolean; style?: Style }) {
  const fg = solid ? C.white : toneFg[tone];
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 5, padding: "5px 10px", borderRadius: 999, background: solid ? toneFg[tone] : toneBg[tone], flexShrink: 0, ...style }}>
      {icon && <Icon name={icon} size={12} color={fg} weight={600} />}
      <T k="label" c={fg} w={600} lines={1}>{text}</T>
    </span>
  );
}

/** Inline banner: tinted panel with icon, text and an optional link action. */
export function Banner({ tone = "info", icon = "info", title, text, actionTitle, onAction, style }: {
  tone?: Tone; icon?: IconName; title?: string; text: ReactNode; actionTitle?: string; onAction?: () => void; style?: Style;
}) {
  return (
    <HStack align="start" gap={12} style={{ padding: "14px 16px", borderRadius: 14, background: toneBg[tone], ...style }}>
      <Icon name={icon} size={18} color={tone === "info" ? C.heading : toneBanner[tone]} style={{ marginTop: 2 }} />
      <TD k="caption" c={toneBanner[tone]} s={14} style={{ flex: 1 }}>
        {title && <span style={{ fontWeight: 600 }}>{title} </span>}
        {text}
      </TD>
      {actionTitle && <Link title={actionTitle} k="caption" onClick={onAction} style={{ minHeight: 20 }} />}
    </HStack>
  );
}

/** Centered state: circle, title, body, primary and text actions. */
export function FullState({ icon, tone = "info", title, message = "", spinning = false, primary, primaryIcon, primaryKind = "primary", secondary, captain = false, onPrimary, onSecondary, style }: {
  icon: IconName; tone?: Tone; title: string; message?: string; spinning?: boolean; primary?: string; primaryIcon?: IconName;
  primaryKind?: ButtonKind; secondary?: string; captain?: boolean; onPrimary?: () => void; onSecondary?: () => void; style?: Style;
}) {
  return (
    <VStack align="center" style={{ flex: 1, width: "100%", padding: `20px ${captain ? S.gutterCaptain : 0}px`, ...style }}>
      <div style={{ flex: 1, minHeight: 20 }} />
      <StateCircle icon={icon} tone={tone} size={captain ? 112 : 96} spinning={spinning} />
      <TD k="section" w={600} s={captain ? 23 : 21} center style={{ marginTop: 22 }}>{title}</TD>
      {message && <TD k="body" s={captain ? 16.5 : 15} center style={{ marginTop: 10, marginBottom: 24 }}>{message}</TD>}
      {!message && <div style={{ height: 10 }} />}
      {primary && <Button title={primary} icon={primaryIcon} kind={primaryKind} size={captain ? "captain" : "regular"} onClick={onPrimary} />}
      {secondary && <Button title={secondary} kind="text" onClick={onSecondary} style={{ marginTop: 6 }} />}
      <div style={{ flex: 2, minHeight: 40 }} />
    </VStack>
  );
}

/** Selection tile: icon box, title, subtitle, trailing value. */
export function SelectionTile({ icon, title, subtitle, trailing, selected = false, radio = false, iconTone = "info", onClick }: {
  icon: IconName; title: string; subtitle?: string; trailing?: string; selected?: boolean; radio?: boolean; iconTone?: Tone; onClick?: () => void;
}) {
  return (
    <Tap onClick={onClick} style={{
      display: "flex", alignItems: "center", gap: 14, padding: 16, width: "100%", textAlign: "left", borderRadius: 16,
      background: selected ? C.primaryTint : C.white, boxShadow: `inset 0 0 0 ${selected ? 2 : 1}px ${selected ? C.primary : C.border}`,
    }}>
      <IconBox icon={icon} size={48} tone={iconTone} />
      <VStack gap={1} style={{ flex: 1, minWidth: 0 }}>
        <TD k="title">{title}</TD>
        {subtitle && <TD k="caption">{subtitle}</TD>}
      </VStack>
      {trailing && <T k="valueStrong" mono>{trailing}</T>}
      {radio && <Radio on={selected} />}
    </Tap>
  );
}

export function Radio({ on }: { on: boolean }) {
  return (
    <span style={{ width: 24, height: 24, borderRadius: 12, boxShadow: `inset 0 0 0 2px ${on ? C.primary : C.muted}`, display: "grid", placeItems: "center", flexShrink: 0 }}>
      {on && <span style={{ width: 12, height: 12, borderRadius: 6, background: C.primary }} />}
    </span>
  );
}

export function Chip({ title, selected = false, icon, enabled = true, strike = false, height = 46, fill = false, onClick }: {
  title: string; selected?: boolean; icon?: IconName; enabled?: boolean; strike?: boolean; height?: number; fill?: boolean; onClick?: () => void;
}) {
  return (
    <Tap onClick={onClick} disabled={!enabled} style={{
      display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 6, padding: "0 15px", minHeight: height,
      width: fill ? "100%" : undefined, borderRadius: R.chip, whiteSpace: "nowrap", flexShrink: 0,
      background: selected ? C.primaryTint : enabled ? C.white : C.canvas,
      boxShadow: `inset 0 0 0 ${selected ? 2 : 1}px ${selected ? C.primary : C.border}`,
    }}>
      {selected ? <Icon name="check" size={14} color={C.primaryStrong} weight={600} /> : icon ? <Icon name={icon} size={15} /> : null}
      <T k="bodyStrong" s={15.5} c={enabled ? (selected ? C.primaryStrong : C.heading) : C.muted} w={selected ? 600 : 400} strike={strike}>{title}</T>
    </Tap>
  );
}

/** Wrapping layout for chips. */
export const Flow = ({ gap = 10, children, style }: { gap?: number; children: ReactNode; style?: Style }) => (
  <div style={{ display: "flex", flexWrap: "wrap", gap, ...style }}>{children}</div>
);

export function Segmented({ options, selection, onChange, height = 46 }: { options: string[]; selection: number; onChange: (i: number) => void; height?: number }) {
  return (
    <HStack style={{ padding: 4, borderRadius: 999, background: C.disabled }}>
      {options.map((o, i) => (
        <Tap key={i} onClick={() => onChange(i)} className="wh-nopress" style={{
          flex: 1, height: height - 8, borderRadius: 999, display: "grid", placeItems: "center", minWidth: 0,
          background: selection === i ? C.white : "transparent", boxShadow: selection === i ? `0 1px 4px ${C.shadow}` : undefined, transition: "background .2s",
        }}>
          <T k="bodyStrong" c={selection === i ? C.heading : C.secondary} w={selection === i ? 600 : 500} lines={1}>{o}</T>
        </Tap>
      ))}
    </HStack>
  );
}

/** Underline tabs (Bookings: Upcoming / Past). */
export function Tabs({ options, selection, onChange }: { options: string[]; selection: number; onChange: (i: number) => void }) {
  return (
    <div style={{ borderBottom: `1px solid ${C.divider}` }}>
      <HStack>
        {options.map((o, i) => (
          <Tap key={i} onClick={() => onChange(i)} className="wh-nopress" style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
            <T k="title" c={selection === i ? C.primaryStrong : C.secondary} w={selection === i ? 600 : 500}>{o}</T>
            <span style={{ width: 68, height: 3, borderRadius: 3, background: selection === i ? C.primary : "transparent" }} />
          </Tap>
        ))}
      </HStack>
    </div>
  );
}

/** Number plate tag (outlined, spaced letters). */
export function Plate({ text, large = false }: { text: string; large?: boolean }) {
  return (
    <span style={{
      display: "inline-block", fontSize: large ? 22 : 14.5, fontWeight: 700, letterSpacing: large ? 2 : 1.3, color: C.heading, whiteSpace: "nowrap",
      maxWidth: "100%", overflow: "hidden", textOverflow: "ellipsis", boxSizing: "border-box",
      padding: large ? "8px 12px" : "5px 10px", background: C.white, borderRadius: 6, boxShadow: `inset 0 0 0 1.5px ${C.heading}`, lineHeight: 1.2, flexShrink: 0,
    }}>{text}</span>
  );
}

export function Avatar({ initials, size = 48, photo }: { initials: string; size?: number; photo?: string | null }) {
  if (photo) return <img src={photo} alt="" style={{ width: size, height: size, borderRadius: "50%", objectFit: "cover", flexShrink: 0 }} />;
  return (
    <span style={{ width: size, height: size, borderRadius: "50%", background: C.primaryTint, color: C.primaryStrong, fontSize: size * 0.36, fontWeight: 700, display: "grid", placeItems: "center", flexShrink: 0 }}>{initials}</span>
  );
}

/** List row: icon box, title, subtitle, chevron. */
export function ListRow({ icon, title, subtitle, tone = "info", trailing, chevron = true, iconSize = 40, onClick }: {
  icon: IconName; title: string; subtitle?: string; tone?: Tone; trailing?: string; chevron?: boolean; iconSize?: number; onClick?: () => void;
}) {
  return (
    <Tap onClick={onClick} className="wh-nopress wh-row" style={{ display: "flex", alignItems: "center", gap: 14, padding: "10px 0", width: "100%", textAlign: "left" }}>
      <IconBox icon={icon} size={iconSize} tone={tone} radius={10} />
      <VStack gap={1} style={{ flex: 1, minWidth: 0 }}>
        <TD k="rowTitle">{title}</TD>
        {subtitle && <TD k="caption">{subtitle}</TD>}
      </VStack>
      {trailing && <T k="caption">{trailing}</T>}
      {chevron && <Icon name="chevron" size={15} color={C.secondary} weight={500} />}
    </Tap>
  );
}

export const Divider = ({ inset = 0 }: { inset?: number }) => <div style={{ height: 1, background: C.divider, marginLeft: inset }} />;

/** Key / value rows in an outlined card (Check and pay, booking detail). */
export function KeyValueCard({ rows, boldLast = false }: { rows: [string, string][]; boldLast?: boolean }) {
  return (
    <div style={{ ...outlined(0, 16), padding: "2px 16px" }}>
      {rows.map(([k, v], i) => (
        <div key={i}>
          <HStack align="start" gap={12} style={{ padding: "12px 0" }}>
            <T k="body" c={C.secondary}>{k}</T>
            <Spacer />
            <T k={boldLast && i === rows.length - 1 ? "valueStrong" : "bodyStrong"} c={C.heading} mono style={{ textAlign: "right" }}>{v}</T>
          </HStack>
          {i < rows.length - 1 && <Divider />}
        </div>
      ))}
    </div>
  );
}

/** Vertical status steps (Booked → Captain on the way → Washing → Check photos). */
export function StatusSteps({ steps, current, spacing = 26 }: { steps: { title: string; detail?: string }[]; current: number; spacing?: number }) {
  return (
    <VStack>
      {steps.map((s, i) => (
        <HStack key={i} align="stretch" gap={14}>
          <VStack align="center">
            {i < current ? (
              <span style={{ width: 24, height: 24, borderRadius: 12, background: C.success, display: "grid", placeItems: "center" }}><Icon name="check" size={13} color={C.onSuccess} weight={700} /></span>
            ) : i === current ? (
              <span style={{ width: 24, height: 24, borderRadius: 12, background: C.primary, display: "grid", placeItems: "center" }}><span style={{ width: 8, height: 8, borderRadius: 4, background: "#fff" }} /></span>
            ) : (
              <span style={{ width: 24, height: 24, borderRadius: 12, boxShadow: `inset 0 0 0 2px ${C.border}` }} />
            )}
            {i < steps.length - 1 && <div style={{ width: 2, flex: 1, minHeight: spacing - 4, background: i < current ? C.success : C.border }} />}
          </VStack>
          <VStack gap={2} style={{ paddingTop: 1, paddingBottom: i < steps.length - 1 ? 4 : 0 }}>
            <TD k="rowTitle" c={i === current ? C.primaryStrong : i < current ? C.heading : C.secondary} w={i <= current ? 600 : 400}>{s.title}</TD>
            {s.detail && <TD k="caption">{s.detail}</TD>}
          </VStack>
        </HStack>
      ))}
    </VStack>
  );
}

export type PhotoState = "empty" | "uploading" | "done" | "failed";

/** Photo slot: dashed empty slot with camera, or a placeholder photo with state. */
export function PhotoSlot({ label, state = "empty", tag, tagTone = "mute", height = 126, showLabelBelow = false, icon = "car", onClick }: {
  label: string; state?: PhotoState; tag?: string; tagTone?: Tone; height?: number; showLabelBelow?: boolean; icon?: IconName; onClick?: () => void;
}) {
  return (
    <VStack gap={6} style={{ width: "100%" }}>
      <Tap onClick={onClick} style={{
        position: "relative", height, width: "100%", borderRadius: 12, display: "grid", placeItems: "center",
        background: state === "failed" ? C.errorTint : state === "empty" ? "transparent" : C.photo,
        border: state === "empty" ? `1px dashed ${C.dashed}` : undefined,
      }}>
        {state === "empty" && (
          <VStack gap={6} align="center"><Icon name="camera" size={22} color={C.primaryStrong} />{!showLabelBelow && <T k="label" c={C.primaryStrong}>{label}</T>}</VStack>
        )}
        {state === "failed" && (
          <VStack gap={6} align="center"><Icon name="refresh" size={20} color={C.destructive} weight={500} /><T k="label" c={C.destructive}>Retry upload</T></VStack>
        )}
        {(state === "uploading" || state === "done") && <Icon name={icon} size={22} color={C.secondary} />}
        {state === "uploading" && (
          <div style={{ position: "absolute", left: 8, right: 8, bottom: 8, height: 4, borderRadius: 4, background: C.track, overflow: "hidden" }}>
            <div className="wh-upload" style={{ height: 4, background: C.primary, borderRadius: 4 }} />
          </div>
        )}
        {state === "done" && (
          <span style={{ position: "absolute", top: 8, right: 8, width: 22, height: 22, borderRadius: 11, background: C.success, display: "grid", placeItems: "center" }}>
            <Icon name="check" size={12} color={C.onSuccess} weight={700} />
          </span>
        )}
        {tag && state !== "empty" && <PhotoTag tag={tag} tone={tagTone} />}
      </Tap>
      {(showLabelBelow || state !== "empty") && <T k="label" c={C.heading} w={500}>{label}</T>}
    </VStack>
  );
}

const PhotoTag = ({ tag, tone, pad = 8 }: { tag: string; tone: Tone; pad?: number }) => (
  <span style={{ position: "absolute", left: pad, bottom: pad, padding: "3px 8px", borderRadius: 999, background: tone === "ok" ? C.success : C.inverse }}>
    <T k="small" c={tone === "ok" ? C.onSuccess : C.white} w={600}>{tag}</T>
  </span>
);

/** Grey placeholder used where a real photo will be (mock mode). */
export function PhotoPlaceholder({ icon = "car", tag, tagTone = "mute", radius = 10, height, children, style }: {
  icon?: IconName; tag?: string; tagTone?: Tone; radius?: number; height: number; children?: ReactNode; style?: Style;
}) {
  return (
    <div style={{ position: "relative", flex: 1, height, borderRadius: radius, background: C.photo, display: "grid", placeItems: "center", ...style }}>
      <Icon name={icon} size={20} color={C.secondary} />
      {tag && <PhotoTag tag={tag} tone={tagTone} pad={6} />}
      {children}
    </div>
  );
}

// MARK: - Inputs

/** Outlined field with the label sitting on the border, helper and error text. */
export function TextField({ label, value, onChange, placeholder = "", helper, error, leadingIcon, inputMode, type = "text", caps = "none", large = false, autoFocus = false, focusTrigger, onSubmit, enterKey }: {
  label: string; value: string; onChange: (v: string) => void; placeholder?: string; helper?: string; error?: string | null;
  leadingIcon?: IconName; inputMode?: React.HTMLAttributes<HTMLInputElement>["inputMode"]; type?: string;
  caps?: "none" | "characters" | "words"; large?: boolean; autoFocus?: boolean; focusTrigger?: number; onSubmit?: () => void; enterKey?: "done" | "next";
}) {
  const [focused, setFocused] = useState(false);
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => { if (autoFocus) { const t = setTimeout(() => ref.current?.focus({ preventScroll: true }), 350); return () => clearTimeout(t); } }, [autoFocus]);
  useEffect(() => { if (focusTrigger) ref.current?.focus({ preventScroll: true }); }, [focusTrigger]);
  const border = error ? C.destructive : focused ? C.primary : C.border;
  return (
    <VStack gap={6} style={{ width: "100%" }}>
      <div style={{ position: "relative" }}>
        <HStack gap={10} style={{ padding: "0 16px", height: large ? 62 : 52, background: C.white, borderRadius: R.field, boxShadow: `inset 0 0 0 ${focused || error ? 2 : 1}px ${border}` }}>
          {leadingIcon && <Icon name={leadingIcon} size={17} color={C.secondary} />}
          <input
            ref={ref}
            className="wh-input"
            value={value}
            placeholder={placeholder}
            type={type}
            inputMode={inputMode}
            enterKeyHint={enterKey}
            autoCapitalize={caps === "characters" ? "characters" : caps === "words" ? "words" : "off"}
            autoCorrect="off"
            spellCheck={false}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
            onChange={(e) => onChange(caps === "characters" ? e.target.value.toUpperCase() : e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") onSubmit?.(); }}
            style={{ fontSize: large ? 24 : 17, letterSpacing: large ? 1.5 : 0 }}
          />
        </HStack>
        {label && (focused || value || error) && (
          <span style={{ position: "absolute", left: 12, top: -8, padding: "0 4px", background: C.white }}>
            <T k="label" c={error ? C.destructive : focused ? C.primaryStrong : C.secondary}>{label}</T>
          </span>
        )}
      </div>
      {error ? (
        <HStack gap={6}><Icon name="warning" size={13} color={C.destructive} /><T k="caption" c={C.destructive}>{error}</T></HStack>
      ) : helper ? <TD k="caption">{helper}</TD> : null}
    </VStack>
  );
}

/** Multi-line note box. */
export function TextArea({ value, onChange, placeholder = "", height = 112 }: { value: string; onChange: (v: string) => void; placeholder?: string; height?: number }) {
  return (
    <textarea className="wh-textarea" value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)}
      style={{ height, borderRadius: 12, boxShadow: `inset 0 0 0 1px ${C.border}` }} />
  );
}

/** OTP boxes backed by one hidden text field. */
export function OtpField({ code, onChange, length = 6, error = false, boxSize = 48, autoFocus = true }: {
  code: string; onChange: (v: string) => void; length?: number; error?: boolean; boxSize?: number; autoFocus?: boolean;
}) {
  const ref = useRef<HTMLInputElement>(null);
  const [focused, setFocused] = useState(false);
  useEffect(() => { if (autoFocus) { const t = setTimeout(() => ref.current?.focus({ preventScroll: true }), 350); return () => clearTimeout(t); } }, [autoFocus]);
  return (
    <div style={{ position: "relative" }} onClick={() => ref.current?.focus()}>
      <input ref={ref} value={code} inputMode="numeric" autoComplete="one-time-code" aria-label="Code"
        onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
        onChange={(e) => onChange(Validators.digitsOnly(e.target.value).slice(0, length))}
        style={{ position: "absolute", opacity: 0.01, width: 1, height: 1, left: 0, top: 0, border: 0, padding: 0 }} />
      <HStack gap={10}>
        {Array.from({ length }, (_, i) => {
          const ch = code[i] ?? "";
          const cursor = focused && i === Math.min(code.length, length - 1) && !error;
          return (
            <span key={i} style={{
              width: boxSize, height: boxSize * 1.15, borderRadius: 10, background: C.white, display: "grid", placeItems: "center",
              fontSize: boxSize * 0.46, fontWeight: 500, color: C.heading,
              boxShadow: `inset 0 0 0 ${error || cursor ? 2 : 1}px ${error ? C.destructive : cursor ? C.primary : C.border}`,
            }}>{ch}</span>
          );
        })}
      </HStack>
    </div>
  );
}

/** Phone field: "+91" box and the number field. */
export function PhoneField({ number, onChange, error, large = false, autoFocus = true, focusTrigger }: {
  number: string; onChange: (v: string) => void; error?: string | null; large?: boolean; autoFocus?: boolean; focusTrigger?: number;
}) {
  return (
    <HStack align="start" gap={10}>
      <span style={{
        width: large ? 72 : 82, height: large ? 62 : 52, borderRadius: R.field, background: C.white, boxShadow: `inset 0 0 0 1px ${C.border}`,
        display: "grid", placeItems: "center", fontSize: large ? 19 : 17, color: C.heading, flexShrink: 0,
      }}>+91</span>
      <TextField label={large ? "" : "Mobile number"} value={number} placeholder="9876543210" error={error} inputMode="tel" type="tel"
        large={large} autoFocus={autoFocus} focusTrigger={focusTrigger}
        onChange={(v) => onChange(Validators.digitsOnly(v).slice(0, 10))} />
    </HStack>
  );
}

/** iOS switch. */
export function Toggle({ on, onChange, disabled = false, tint = C.primary, label }: { on: boolean; onChange: (v: boolean) => void; disabled?: boolean; tint?: string; label?: string }) {
  return (
    <button type="button" role="switch" aria-checked={on} aria-label={label} disabled={disabled} className="wh-tap"
      onClick={(e) => { e.stopPropagation(); onChange(!on); }}
      style={{ width: 51, height: 31, borderRadius: 16, background: on ? tint : "#E9E9EB", position: "relative", flexShrink: 0, transition: "background .2s", opacity: disabled ? 0.5 : 1 }}>
      <span style={{ position: "absolute", top: 2, left: on ? 22 : 2, width: 27, height: 27, borderRadius: 14, background: "#fff", boxShadow: "0 3px 8px rgba(0,0,0,.15), 0 1px 1px rgba(0,0,0,.16)", transition: "left .2s" }} />
    </button>
  );
}

/** A labelled row with a switch on the right (SwiftUI Toggle with a label). */
export function ToggleRow({ on, onChange, disabled, tint, children, style }: { on: boolean; onChange: (v: boolean) => void; disabled?: boolean; tint?: string; children: ReactNode; style?: Style }) {
  return (
    <HStack gap={12} style={{ opacity: disabled ? 0.6 : 1, ...style }}>
      <div style={{ flex: 1, minWidth: 0 }}>{children}</div>
      <Toggle on={on} onChange={onChange} disabled={disabled} tint={tint} />
    </HStack>
  );
}

/** Page dots (TabView page style). */
export function PageDots({ count, index, light = true }: { count: number; index: number; light?: boolean }) {
  return (
    <HStack gap={8} style={{ justifyContent: "center" }}>
      {Array.from({ length: count }, (_, i) => (
        <span key={i} style={{ width: 7, height: 7, borderRadius: 4, background: light ? (i === index ? "#fff" : "rgba(255,255,255,.35)") : i === index ? C.heading : C.border }} />
      ))}
    </HStack>
  );
}

/** Horizontal pager (TabView .page): swipe or scroll between pages. */
export function Pager({ count, index, onIndex, render, style }: { count: number; index: number; onIndex: (i: number) => void; render: (i: number) => ReactNode; style?: Style }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const target = index * el.clientWidth;
    if (Math.abs(el.scrollLeft - target) > 2) el.scrollTo({ left: target, behavior: "smooth" });
  }, [index]);
  return (
    <div ref={ref} className="wh-pager" style={style}
      onScroll={(e) => { const el = e.currentTarget; const i = Math.round(el.scrollLeft / el.clientWidth); if (i !== index) onIndex(i); }}>
      {Array.from({ length: count }, (_, i) => <div key={i} className="wh-page">{render(i)}</div>)}
    </div>
  );
}
