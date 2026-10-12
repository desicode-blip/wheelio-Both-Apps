"use client";

import { createContext, useContext, useEffect, useRef } from "react";
import type { AppStore, Router } from "./store";
import { IsTop } from "../shell/StackView";
import { Support } from "../lib/fmt";

export const AppCtx = createContext<{ store: AppStore; router: Router } | null>(null);

export function useApp() {
  const v = useContext(AppCtx);
  if (!v) throw new Error("useApp outside the customer app");
  return v;
}

/** Shared "call support" action for footers. */
export const callSupport = () => Support.call();

/** SwiftUI onAppear: runs when the screen becomes the top of the stack (again). */
export function useOnAppear(fn: () => void | (() => void)) {
  const top = useContext(IsTop);
  const f = useRef(fn);
  f.current = fn;
  useEffect(() => {
    if (top) return f.current() ?? undefined;
  }, [top]);
}
