// Navigation stack (NavigationStack path) for a phone app. Routes are plain objects with `n`.

import { newId } from "./fmt";

export type Entry<R> = { key: string; route: R };

export class Nav<R extends { n: string }> {
  path: Entry<R>[] = [];
  tab = 0;

  push(r: R) { this.path = [...this.path, { key: newId("r"), route: r }]; }
  pop() { if (this.path.length) this.path = this.path.slice(0, -1); }
  popToRoot() { this.path = []; }
  replace(routes: R[]) { this.path = routes.map((route) => ({ key: newId("r"), route })); }
  /** Keep the first `count` entries. */
  keep(count: number) { this.path = this.path.slice(0, count); }
  get last(): R | undefined { return this.path[this.path.length - 1]?.route; }
  is(name: R["n"]) { return this.last?.n === name; }
  indexOf(name: R["n"]) { return this.path.findIndex((e) => e.route.n === name); }
}
