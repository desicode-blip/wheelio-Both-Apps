"use client";

import { createContext, useContext, type ReactNode } from "react";
import { AppBar, FooterBar, TD } from "../ds/components";
import type { CaptainStore, WRouter } from "./store";

export const CaptainCtx = createContext<{ store: CaptainStore; router: WRouter } | null>(null);

export function useCaptain() {
  const v = useContext(CaptainCtx);
  if (!v) throw new Error("useCaptain outside the captain app");
  return v;
}

/** Captain header: back, title (+ subtitle), help. */
export function WHeader({ title = "", subtitle, back = true, help = true }: { title?: string; subtitle?: string; back?: boolean; help?: boolean }) {
  const { router } = useCaptain();
  return (
    <AppBar title={title} subtitle={subtitle} leading={back ? "left" : null} trailing={help ? "help" : null}
      onLeading={() => router.pop()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "4px 4px 0" }} />
  );
}

/** Captain footer: one big action, full width. Support lives in Help. */
export const WFooter = ({ children }: { children: ReactNode }) => <FooterBar showCall={false} captain>{children}</FooterBar>;

/** Bigger, plainer type for the captain app (low cognitive load). */
export const WTitle = ({ children, style }: { children: ReactNode; style?: React.CSSProperties }) => <TD k="screen" w={700} s={27} style={style}>{children}</TD>;
export const WBody = ({ children, style, center }: { children: ReactNode; style?: React.CSSProperties; center?: boolean }) => <TD k="body" s={17} center={center} style={style}>{children}</TD>;
