// Wheelio design system tokens, ported from apps/ios/Shared/DesignSystem/Tokens.swift.
// Both phone apps (Customer and Captain) share this file.

export const Brand = {
  /** "Wheelio" is a working name: change it here only. */
  name: "Wheelio",
  tagline: "Clean wheels, zero hassle",
};

export const C = {
  // action
  primary: "#3160FF",
  primaryStrong: "#1F4AD1",
  success: "#4BD08C",
  onSuccess: "#15352A",
  destructive: "#B3261E",
  // content
  heading: "#172231",
  body: "#2B3A4D",
  secondary: "#5E7087",
  placeholder: "#7E8B9C",
  muted: "#9AA6B6",
  // surface
  white: "#FFFFFF",
  canvas: "#F6F9FD",
  primaryTint: "#EAF0FF",
  successTint: "#E6F8EF",
  waitTint: "#FFF3E0",
  wait: "#8A4500",
  waitText: "#5C2E00",
  errorTint: "#FDECEA",
  errorText: "#7A1A14",
  disabled: "#E8ECF2",
  inverse: "#1B2533",
  camera: "#0E1520",
  cameraPanel: "#1C2636",
  photo: "#E6EAF0",
  map: "#EEF2F7",
  mapBlock: "#E2E8F0",
  mapGreen: "#DDE9D8",
  star: "#F0A030",
  // border
  border: "#DCE2E9",
  divider: "#E1E5EA",
  track: "#DCE5F6",
  dashed: "#9FB3D9",
  grab: "#C9D5E6",
  scrim: "rgba(23,33,48,0.48)",
  shadow: "rgba(23,33,48,0.12)",
  shadowCard: "rgba(23,33,48,0.08)",
} as const;

/** Semantic tone for badges, banners and state circles. Colour is never the only signal. */
export type Tone = "info" | "ok" | "wait" | "error" | "mute";

export const toneBg: Record<Tone, string> = {
  info: C.primaryTint,
  ok: C.successTint,
  wait: C.waitTint,
  error: C.errorTint,
  mute: C.disabled,
};

export const toneFg: Record<Tone, string> = {
  info: C.primaryStrong,
  ok: C.onSuccess,
  wait: C.wait,
  error: C.destructive,
  mute: C.body,
};

export const toneBanner: Record<Tone, string> = {
  info: C.inverse,
  ok: C.onSuccess,
  wait: C.waitText,
  error: C.errorText,
  mute: C.body,
};

export const S = { x1: 4, x2: 8, x3: 12, x4: 16, x5: 20, x6: 24, gutter: 26, gutterCaptain: 16, section: 48 };
export const R = { field: 10, chip: 10, tile: 14, card: 20, button: 26, sheet: 28 };

export type TypeKey =
  | "display" | "screen" | "section" | "value" | "valueStrong" | "title" | "rowTitle" | "body" | "bodyStrong"
  | "action" | "caption" | "label" | "appBarTitle" | "bigMoney" | "hugeMoney" | "small";

type TypeSpec = { size: number; line: number; weight: number; color: string };

export const TYPE: Record<TypeKey, TypeSpec> = {
  display: { size: 40, line: 48, weight: 700, color: C.heading },
  screen: { size: 26, line: 32, weight: 700, color: C.heading },
  section: { size: 20, line: 26, weight: 600, color: C.heading },
  value: { size: 17, line: 22, weight: 400, color: C.heading },
  valueStrong: { size: 17, line: 22, weight: 600, color: C.heading },
  appBarTitle: { size: 17, line: 22, weight: 600, color: C.heading },
  title: { size: 16, line: 21, weight: 600, color: C.heading },
  rowTitle: { size: 16, line: 21, weight: 400, color: C.heading },
  body: { size: 15, line: 22, weight: 400, color: C.secondary },
  bodyStrong: { size: 15, line: 22, weight: 400, color: C.body },
  action: { size: 16.5, line: 21, weight: 600, color: C.white },
  caption: { size: 13, line: 18, weight: 400, color: C.secondary },
  label: { size: 12.5, line: 16, weight: 600, color: C.secondary },
  small: { size: 11.5, line: 14, weight: 400, color: C.secondary },
  bigMoney: { size: 44, line: 52, weight: 700, color: C.heading },
  hugeMoney: { size: 56, line: 64, weight: 700, color: C.heading },
};

export const W = { regular: 400, medium: 500, semibold: 600, bold: 700 } as const;
