"use client";

// Renders a NavigationStack: the root plus every pushed screen, each in its own full-phone layer.
// Lower screens stay mounted (so their state survives, like SwiftUI) and hidden; the top one
// slides in from the right on push and back out on pop.

import { createContext, useEffect, useRef, useState, type ReactNode } from "react";
import type { Entry } from "../lib/nav";
import { OverlayHost } from "../ds/components";

export const IsTop = createContext(true);

type Transition<R> = { inKey: string; inCls: string; out: Entry<R> | null; outKey: string; outCls: string };

export function StackView<R>({ root, entries, render }: { root: ReactNode; entries: Entry<R>[]; render: (r: R, key: string) => ReactNode }) {
  const prev = useRef<Entry<R>[]>(entries);
  const trans = useRef<Transition<R> | null>(null);
  const [, force] = useState(0);
  const topKey = entries.length ? entries[entries.length - 1].key : "root";

  // Work out the transition while rendering, so a screen that is leaving never unmounts
  // (and remounts) between renders.
  if (prev.current !== entries) {
    const before = prev.current;
    prev.current = entries;
    const oldTop = before.length ? before[before.length - 1].key : "root";
    if (oldTop !== topKey) {
      const stillThere = oldTop === "root" || entries.some((e) => e.key === oldTop);
      const out = stillThere ? null : before.find((e) => e.key === oldTop) ?? null;
      const isPop = topKey === "root" || before.some((e) => e.key === topKey);
      trans.current = isPop
        ? { inKey: topKey, inCls: "wh-pop-in", out, outKey: oldTop, outCls: "wh-pop-out" }
        : { inKey: topKey, inCls: "wh-push-in", out, outKey: oldTop, outCls: "wh-push-out" };
    }
  }

  useEffect(() => {
    if (!trans.current) return;
    const t = setTimeout(() => { trans.current = null; force((n) => n + 1); }, 340);
    return () => clearTimeout(t);
  }, [topKey]);

  const tr = trans.current;
  const cls = (k: string) => (tr && k === tr.inKey ? tr.inCls : tr && k === tr.outKey ? tr.outCls : "");
  const layers: { key: string; node: ReactNode; exiting?: boolean }[] = [
    { key: "root", node: root },
    ...entries.map((e) => ({ key: e.key, node: render(e.route, e.key) })),
  ];
  if (tr?.out && !entries.some((e) => e.key === tr.out!.key)) layers.push({ key: tr.out.key, node: render(tr.out.route, tr.out.key), exiting: true });

  return (
    <>
      {layers.map((l) => {
        const isTop = l.key === topKey;
        const c = cls(l.key);
        const visible = isTop || c !== "";
        const z = l.exiting ? (c === "wh-pop-out" ? 3 : 1) : isTop ? 2 : 1;
        return (
          <Layer key={l.key} className={`wh-layer ${c}`} isTop={isTop}
            style={{ visibility: visible ? "visible" : "hidden", zIndex: z, pointerEvents: isTop ? "auto" : "none" }}>
            {l.node}
          </Layer>
        );
      })}
    </>
  );
}

/** One full-phone layer; sheets and alerts opened inside it render into it. */
export function Layer({ className = "wh-layer", isTop = true, style, children }: { className?: string; isTop?: boolean; style?: React.CSSProperties; children: ReactNode }) {
  const [host, setHost] = useState<HTMLDivElement | null>(null);
  return (
    <div ref={setHost} className={className} aria-hidden={!isTop} style={style}>
      <OverlayHost.Provider value={host}>
        <IsTop.Provider value={isTop}>{children}</IsTop.Provider>
      </OverlayHost.Provider>
    </div>
  );
}
