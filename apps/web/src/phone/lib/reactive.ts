// Tiny observable state, standing in for Swift's @Observable stores.
// `reactive(obj)` returns a deep proxy: any property set at any depth notifies subscribers
// (batched per microtask). Keep state to plain objects, arrays and Dates (no Set/Map).

import { useSyncExternalStore } from "react";

export class Hub {
  private listeners = new Set<() => void>();
  private version = 0;
  private queued = false;
  subscribe = (l: () => void) => { this.listeners.add(l); return () => { this.listeners.delete(l); }; };
  snapshot = () => this.version;
  notify = () => {
    if (this.queued) return;
    this.queued = true;
    queueMicrotask(() => {
      this.queued = false;
      this.version++;
      this.listeners.forEach((l) => l());
    });
  };
}

const RAW = Symbol("raw");

export function reactive<T extends object>(target: T, hub: Hub): T {
  const cache = new WeakMap<object, object>();
  const wrap = (o: object): object => {
    if ((o as { [RAW]?: object })[RAW]) return o;
    const hit = cache.get(o);
    if (hit) return hit;
    const p = new Proxy(o, {
      get(t, k, r) {
        if (k === RAW) return t;
        const v = Reflect.get(t, k, r);
        if (v && typeof v === "object" && !(v instanceof Date) && !(v instanceof Promise)) return wrap(v);
        return v;
      },
      set(t, k, v, r) {
        const raw = v && typeof v === "object" ? ((v as { [RAW]?: object })[RAW] ?? v) : v;
        const old = Reflect.get(t, k, r);
        const ok = Reflect.set(t, k, raw, r);
        if (old !== raw || Array.isArray(t)) hub.notify();
        return ok;
      },
      deleteProperty(t, k) {
        const ok = Reflect.deleteProperty(t, k);
        hub.notify();
        return ok;
      },
    });
    cache.set(o, p);
    return p;
  };
  return wrap(target) as T;
}

export function useHub(hub: Hub) {
  return useSyncExternalStore(hub.subscribe, hub.snapshot, hub.snapshot);
}

/** Cancellable async task, like a Swift Task. */
export class Job {
  cancelled = false;
  cancel() { this.cancelled = true; }
}

export function run(fn: (job: Job) => Promise<void>): Job {
  const j = new Job();
  fn(j).catch(() => {});
  return j;
}
