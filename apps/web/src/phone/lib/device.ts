// Browser stand-ins for iOS device APIs: system sounds, haptics, notification permission,
// system notifications and phone calls.

export type Permission = "unknown" | "allowed" | "denied";

let audio: AudioContext | null = null;

/** Short two-tone chime (AudioServicesPlaySystemSound 1007). */
export function ding() {
  try {
    audio ??= new AudioContext();
    const t = audio.currentTime;
    [880, 1320].forEach((f, i) => {
      const o = audio!.createOscillator();
      const g = audio!.createGain();
      o.frequency.value = f;
      o.type = "sine";
      g.gain.setValueAtTime(0.0001, t + i * 0.12);
      g.gain.exponentialRampToValueAtTime(0.18, t + i * 0.12 + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + i * 0.12 + 0.3);
      o.connect(g).connect(audio!.destination);
      o.start(t + i * 0.12);
      o.stop(t + i * 0.12 + 0.32);
    });
  } catch {}
}

/** Haptic feedback where the browser supports it. */
export function buzz(pattern: number | number[] = 30) {
  try { navigator.vibrate?.(pattern); } catch {}
}

export function systemPermission(): Permission {
  if (typeof Notification === "undefined") return "unknown";
  return Notification.permission === "granted" ? "allowed" : Notification.permission === "denied" ? "denied" : "unknown";
}

export async function requestPermission(): Promise<Permission> {
  if (typeof Notification === "undefined") return "unknown";
  try {
    const p = await Notification.requestPermission();
    return p === "granted" ? "allowed" : p === "denied" ? "denied" : "unknown";
  } catch {
    return "unknown";
  }
}

/** Notification while the app is in the background (tab hidden). */
export function systemNotify(title: string, body: string, silent: boolean) {
  try {
    if (typeof Notification !== "undefined" && Notification.permission === "granted") new Notification(title, { body, silent });
  } catch {}
}

export const appIsActive = () => typeof document === "undefined" || document.visibilityState === "visible";

/** On a phone this dials; on a laptop it tells the app to show a note instead. */
export function call(number: string) {
  if (typeof window === "undefined") return;
  if (window.matchMedia("(pointer: coarse)").matches) window.location.href = `tel:${number}`;
  else window.dispatchEvent(new CustomEvent("wh-call", { detail: number }));
}

/** Read a picked image file as a data URL (PhotosPicker stand-in). */
export function pickImage(): Promise<string | null> {
  return new Promise((resolve) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/*";
    input.onchange = () => {
      const f = input.files?.[0];
      if (!f) return resolve(null);
      const r = new FileReader();
      r.onload = () => resolve(String(r.result));
      r.onerror = () => resolve(null);
      r.readAsDataURL(f);
    };
    input.click();
  });
}

/** Speak text in a language (AVSpeechSynthesizer stand-in). Resolves when finished. */
export function speak(text: string, lang: string, onEnd: () => void): () => void {
  if (typeof speechSynthesis === "undefined") {
    const t = setTimeout(onEnd, 6000);
    return () => clearTimeout(t);
  }
  speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.lang = lang;
  u.rate = 0.9;
  let done = false;
  const finish = () => { if (!done) { done = true; onEnd(); } };
  u.onend = finish;
  u.onerror = finish;
  speechSynthesis.speak(u);
  return () => { done = true; speechSynthesis.cancel(); };
}
