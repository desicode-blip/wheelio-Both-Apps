"use client";

import { useEffect } from "react";
import { Brand, C, S } from "../../ds/tokens";
import { Button, HStack, IconBox, TD, VStack } from "../../ds/components";
import type { IconName } from "../../ds/icons";
import { useApp } from "../ctx";

/** Brand mark: blue rounded square with the ring, plus the name token. */
export function BrandMark({ size = 34, light = false, showName = true }: { size?: number; light?: boolean; showName?: boolean }) {
  return (
    <HStack gap={size * 0.3}>
      <div style={{ position: "relative", width: size, height: size, borderRadius: size * 0.24, background: light ? "transparent" : C.primary, display: "grid", placeItems: "center", flexShrink: 0 }}>
        <span style={{ width: size * 0.56, height: size * 0.56, borderRadius: "50%", boxShadow: `inset 0 0 0 ${size * 0.1}px #fff`, display: "grid", placeItems: "center" }}>
          <span style={{ width: size * 0.2, height: size * 0.2, borderRadius: "50%", background: "#fff" }} />
        </span>
      </div>
      {showName && <span style={{ fontSize: size * (light ? 1.2 : 0.8), fontWeight: 700, color: light ? "#fff" : C.heading, letterSpacing: -0.3 }}>{Brand.name}</span>}
    </HStack>
  );
}

// MARK: C01 Splash

export function SplashScreen({ onDone }: { onDone: () => void }) {
  useEffect(() => {
    const t = setTimeout(onDone, 1300);
    return () => clearTimeout(t);
  }, [onDone]);
  return (
    <div className="wh-fill" style={{ background: C.primary, alignItems: "center", justifyContent: "center", gap: 14 }}>
      <BrandMark size={40} light />
      <TD k="body" c="rgba(255,255,255,.92)">{Brand.tagline}</TD>
    </div>
  );
}

// MARK: C02 Welcome

export function WelcomeScreen() {
  const { store, router } = useApp();
  const feature = (icon: IconName, title: string, sub: string) => (
    <HStack gap={14}>
      <IconBox icon={icon} size={48} radius={12} />
      <VStack gap={1}>
        <TD k="title" w={500}>{title}</TD>
        <TD k="caption">{sub}</TD>
      </VStack>
    </HStack>
  );
  return (
    <div className="wh-fill" style={{ background: C.white, padding: `calc(var(--sat) + 20px) ${S.gutter}px calc(16px + var(--sab))` }}>
      <BrandMark />
      <TD k="display" style={{ marginTop: 40 }}>{"Clean wheels,\nzero hassle"}</TD>
      <TD k="body" s={16.5} style={{ marginTop: 14 }}>Book a wash for your car or bike. Pay only after you see the photos.</TD>
      <VStack gap={18} style={{ marginTop: 36 }}>
        {feature("camera", "Photo proof, every wash", "Before and after, same angles")}
        {feature("shield", "Money held safely", "Released only when you approve")}
        {feature("clock", "You pick the time", "A nearby captain comes to your parking")}
      </VStack>
      <div style={{ flex: 1 }} />
      {/* One way in. Returning customers say so at login, just before payment. */}
      <Button title="Book a wash" onClick={() => { store.startNewBooking(); router.push({ n: "vehicleType" }); }} />
    </div>
  );
}
