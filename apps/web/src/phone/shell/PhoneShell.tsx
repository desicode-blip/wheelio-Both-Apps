"use client";

// Device chrome for the web port. On a laptop the app sits in an iPhone-sized frame in the
// middle of the page with blank space either side; on a phone it fills the screen.

import Link from "next/link";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { C } from "../ds/tokens";

const PHONE_W = 390;
const PHONE_H = 844;

export function PhoneShell({ app, statusLight = false, children }: { app: "customer" | "captain"; statusLight?: boolean; children: ReactNode }) {
  const [scale, setScale] = useState(1);
  const [now, setNow] = useState<Date | null>(null);
  const frame = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const fit = () => setScale(Math.min(1, (window.innerHeight - 88) / (PHONE_H + 24), (window.innerWidth - 32) / (PHONE_W + 24)));
    fit();
    window.addEventListener("resize", fit);
    return () => window.removeEventListener("resize", fit);
  }, []);

  useEffect(() => {
    setNow(new Date());
    const t = setInterval(() => setNow(new Date()), 15000);
    return () => clearInterval(t);
  }, []);

  const time = now ? `${now.getHours() % 12 || 12}:${String(now.getMinutes()).padStart(2, "0")}` : "9:41";
  const sb = statusLight ? "#fff" : "#000";

  return (
    <div className="wh-stage">
      <nav className="wh-switch" aria-label="Choose app">
        <Link href="/app" className={app === "customer" ? "on" : ""}>Customer</Link>
        <Link href="/captain" className={app === "captain" ? "on" : ""}>Captain</Link>
      </nav>
      <div className="wh-device" style={{ ["--scale" as string]: scale }} ref={frame}>
        <div className="wh-bezel">
          <div className="wh-phone">
            <div className="wh-statusbar" style={{ color: sb }} aria-hidden>
              <span className="wh-sb-time">{time}</span>
              <span className="wh-island" />
              <span className="wh-sb-icons">
                <svg width="18" height="12" viewBox="0 0 18 12" fill={sb}><rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" /><rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" /></svg>
                <svg width="16" height="12" viewBox="0 0 16 12" fill={sb}><path d="M8 2.3c2.3 0 4.4.9 6 2.4l1.1-1.2A10.2 10.2 0 0 0 8 .6C5.3.6 2.8 1.6.9 3.5L2 4.7a8.6 8.6 0 0 1 6-2.4Zm0 3.4c1.4 0 2.6.5 3.6 1.4l1.1-1.2A7 7 0 0 0 8 4a7 7 0 0 0-4.7 1.9l1.1 1.2c1-.9 2.2-1.4 3.6-1.4Zm0 3.3c-.6 0-1.2.2-1.6.6L8 11.4l1.6-1.8A2.3 2.3 0 0 0 8 9Z" /></svg>
                <svg width="27" height="13" viewBox="0 0 27 13" fill="none"><rect x=".5" y=".5" width="23" height="12" rx="3.5" stroke={sb} opacity=".4" /><rect x="2" y="2" width="20" height="9" rx="2" fill={sb} /><path d="M25 4.5v4c.8-.3 1.3-1.1 1.3-2s-.5-1.7-1.3-2Z" fill={sb} opacity=".45" /></svg>
              </span>
            </div>
            <div className="wh-app" style={{ background: C.white }}>{children}</div>
            <div className="wh-home" style={{ background: statusLight ? "rgba(255,255,255,.7)" : "#000" }} aria-hidden />
          </div>
        </div>
      </div>
    </div>
  );
}
