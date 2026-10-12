import {
  ArrowRight, ArrowUp, Armchair, Ban, Landmark, BatteryLow, Bell, BellOff, Bike, Bird, Building2, Calendar, Camera, Car, Check,
  ChevronLeft, ChevronRight, CircleCheck, CircleHelp, CircleStop, Clock, DoorOpen, Download, Droplet, Eye, FileText, Flag,
  FastForward, Gift, Hand, House, IdCard, Image as ImageIcon, Images, IndianRupee, Info, Languages, Layers, List, LocateFixed, Lock,
  LogOut, Mail, MailOpen, Maximize2, Megaphone, MessageCircle, Mic, Minus, MapPin, Moon, Navigation, PaintBucket, Pause, Pencil,
  PersonStanding, Phone, Play, Plus, Power, RotateCcw, RotateCw, ScanFace, Search, Settings, ShieldCheck, Sofa, Sparkle, Sparkles,
  Spline, Square, SquareCheck, SquareParking, Star, Sun, Timer, Trash2, TriangleAlert, Upload, User, Users, Video, Volume2, VolumeX,
  Wind, WifiOff, X, Zap, ZoomIn, Footprints, type LucideIcon,
} from "lucide-react";
import type { CSSProperties } from "react";
import { C } from "./tokens";

/** Icon names from the design layers (Icon/left, Icon/help …), mirroring WIcon in Icons.swift. */
const MAP = {
  left: ChevronLeft, close: X, help: CircleHelp, phone: Phone, call: Phone, chevron: ChevronRight, check: Check,
  checkCircle: CircleCheck, plus: Plus, minus: Minus, bike: Bike, car: Car, suv: Car, camera: Camera, video: Video, mic: Mic,
  play: Play, pause: Pause, trash: Trash2, image: ImageIcon, gallery: ImageIcon, location: MapPin, locate: Navigation,
  search: Search, home: House, calendar: Calendar, clock: Clock, shield: ShieldCheck, rupee: IndianRupee, gift: Gift, star: Star,
  starFill: Star, bell: Bell, user: User, logout: LogOut, edit: Pencil, doc: FileText, receipt: FileText, flag: Flag, zoom: ZoomIn,
  info: Info, warning: TriangleAlert, error: TriangleAlert, wifiOff: WifiOff, lock: Lock, drop: Droplet, sparkle: Sparkle,
  refresh: RotateCw, arrowRight: ArrowRight, arrowUp: ArrowUp, layers: Layers, parking: SquareParking, door: DoorOpen,
  whatsapp: MessageCircle, chat: MessageCircle, gear: Settings, bellSlash: BellOff, moon: Moon, speakerOff: VolumeX,
  megaphone: Megaphone, bucket: PaintBucket, wipe: Hand, power: Power, list: List, translate: Languages, languages: Languages,
  bank: Landmark, idCard: IdCard, face: ScanFace, sun: Sun, battery: BatteryLow, eye: Eye, ban: Ban, stopwatch: Timer, flash: Zap,
  upload: Upload, scratch: Spline, download: Download, timer: Timer, building: Building2,
  // Extra SF Symbols used directly by some screens.
  wind: Wind, seat: Armchair, sofa: Sofa, bird: Bird, sparkles: Sparkles, figure: PersonStanding, walk: Footprints, family: Users,
  replay: RotateCcw, stop: CircleStop, speaker: Volume2, square: Square, squareCheck: SquareCheck, expand: Maximize2,
  photos: Images, mail: Mail, mailOpen: MailOpen, skip: FastForward, crosshair: LocateFixed,
} satisfies Record<string, LucideIcon>;

export type IconName = keyof typeof MAP;

const FILLED = new Set<IconName>(["starFill", "checkCircle", "play", "pause", "stop", "moon", "bird", "drop", "sparkle", "sparkles"]);

export function Icon({ name, size = 20, color = C.heading, weight = 400, fill, style }: {
  name: IconName; size?: number; color?: string; weight?: number; fill?: boolean; style?: CSSProperties;
}) {
  const Cmp = MAP[name];
  const filled = fill ?? (name === "starFill" || name === "checkCircle");
  const stroke = weight >= 700 ? 2.8 : weight >= 600 ? 2.4 : weight >= 500 ? 2.1 : 1.8;
  return (
    <Cmp
      size={size}
      color={name === "checkCircle" && filled ? "#fff" : color}
      fill={filled ? color : "none"}
      strokeWidth={stroke}
      aria-hidden
      style={{ flexShrink: 0, display: "block", ...style }}
    />
  );
}

export const isFilledIcon = (n: IconName) => FILLED.has(n);
