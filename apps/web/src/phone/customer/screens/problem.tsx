"use client";

import { useState } from "react";
import { C } from "../../ds/tokens";
import {
  AppBar, Badge, Banner, Button, Divider, FooterBar, HStack, KeyValueCard, ListRow, PhotoPlaceholder, PhotoSlot, Screen, SelectionTile,
  StackedFooter, StateCircle, StatusSteps, T, TD, TextArea, TitleBlock, VStack, outlined,
} from "../../ds/components";
import { Icon } from "../../ds/icons";
import { addDays, Fmt } from "../../lib/fmt";
import { useApp, callSupport } from "../ctx";
import { awaitingUPI, Problem, ProblemKinds, type ProblemKind } from "../model";
import { BookingHeader, StepTotal } from "./parts";

// MARK: C31 Report a problem

export function ReportProblemScreen() {
  const { store, router } = useApp();
  const [kind, setKind] = useState<ProblemKind>("notClean");
  return (
    <StepTotal.Provider value={2}>
      <Screen header={<BookingHeader step={1} label="What happened" title="Report a problem" fraction={0.5} />}
        footer={<FooterBar onCall={callSupport}><Button title="Next" onClick={() => router.push({ n: "problemPhotos", kind })} /></FooterBar>}>
        <TitleBlock title="What went wrong?" subtitle="Payment stays on hold while we check." />
        {store.currentOrder?.customerSkippedPhotos && (
          // We still compare the captain's before/after photos; we just can't promise an outcome.
          <Banner tone="wait" icon="camera" title="You skipped the photos at booking." text="So we can’t promise a fix, but we’ll still look into it and get back to you." style={{ marginBottom: 16 }} />
        )}
        <VStack gap={12}>
          {ProblemKinds.map((k) => (
            <SelectionTile key={k} icon={Problem.icon(k)} title={Problem.title(k)} subtitle={Problem.subtitle(k)} selected={kind === k} radio onClick={() => setKind(k)} />
          ))}
        </VStack>
      </Screen>
    </StepTotal.Provider>
  );
}

// MARK: C32 Show us the problem

export function ProblemPhotosScreen({ kind }: { kind: ProblemKind }) {
  const { store, router } = useApp();
  const [note, setNote] = useState("Water streaks on the bonnet and the left mirror wasn’t wiped.");
  const [photos, setPhotos] = useState(2);
  const [sending, setSending] = useState(false);
  return (
    <StepTotal.Provider value={2}>
      <Screen header={<BookingHeader step={2} label="Show us" title="Report a problem" fraction={1} />}
        footer={<FooterBar onCall={callSupport}><Button title="Send report" enabled={photos > 0} loading={sending} onClick={async () => {
          const id = store.currentOrderId;
          if (!id) return;
          setSending(true);
          await store.reportProblem(id, kind, note).catch(() => {});
          setSending(false);
          router.replace([{ n: "disputeStatus" }]);
        }} /></FooterBar>}>
        <TitleBlock title="Show us the problem" subtitle="Take photos from the same angles as the captain’s. We compare all three." />
        <HStack gap={10} align="start" style={{ paddingBottom: 18 }}>
          {[0, 1, 2].map((i) => (
            <div key={i} style={{ flex: 1 }}>
              {i < photos ? <PhotoSlot label={i === 0 ? "Front" : "Close-up"} state="done" height={94} icon={i === 0 ? "car" : "zoom"} />
                : <PhotoSlot label="Add" state="empty" height={94} onClick={() => setPhotos(photos + 1)} />}
            </div>
          ))}
        </HStack>
        <TextArea value={note} onChange={setNote} placeholder="Tell us what you see" height={96} />
      </Screen>
    </StepTotal.Provider>
  );
}

// MARK: C33 under review · C34 upheld · C35 rejected · C36 damage

export function DisputeStatusScreen() {
  const { store, router } = useApp();
  const o = store.currentOrder;
  const d = o?.dispute;
  const header = (title: string) => <AppBar title={title} onLeading={() => router.popToRoot()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "4px 14px 0" }} />;
  switch (d?.outcome ?? "underReview") {
    case "upheld":
      return (
        <Screen header={header(`Report #${d?.ref ?? "WH-20914"}`)}
          footer={<FooterBar onCall={callSupport}><Button title="Book free wash" onClick={() => {
            if (o) { store.startRepeat(o.vehicle); store.draft.useFreeWash = true; }
            router.replace([{ n: "photos" }]);
          }} /></FooterBar>}>
          <VStack align="center">
            <div style={{ paddingTop: 20, paddingBottom: 24 }}><StateCircle icon="gift" tone="ok" /></div>
            <TD k="screen">You’re right, sorry</TD>
            <TD k="body" center style={{ paddingTop: 10, paddingBottom: 24 }}>{d?.decisionNote ?? ""}</TD>
          </VStack>
          <KeyValueCard rows={[
            ["Refund", `${Fmt.rupees(o?.refund?.amount ?? o?.price ?? 149)} to your UPI`],
            ["Bonus", `${d?.creditsAwarded ?? 2} free washes added`],
          ]} />
        </Screen>
      );
    case "rejected":
      return (
        <Screen header={header(`Report #${d?.ref ?? "WH-20914"}`)}
          footer={<StackedFooter><Button title="Okay" onClick={() => router.popToRoot()} /><Button title="Talk to a person" kind="text" onClick={callSupport} /></StackedFooter>}>
          <TitleBlock top={14} title="The wash looks complete" subtitle="We compared your photos with the captain’s. The marks were there before the wash." />
          <HStack gap={8} style={{ paddingBottom: 16 }}>
            <PhotoPlaceholder height={90} icon="car" tag="Before" />
            <PhotoPlaceholder height={90} icon="sparkle" tag="After" tagTone="ok" />
            <PhotoPlaceholder height={90} icon="image">
              <T k="small" style={{ position: "absolute", bottom: 14 }}>Yours</T>
            </PhotoPlaceholder>
          </HStack>
          <Banner tone="info" icon="info" text={d?.decisionNote ?? ""} />
          <TD k="caption" style={{ paddingTop: 16 }}>{`${Fmt.rupees(o?.price ?? 149)} has been released to the captain.`}</TD>
        </Screen>
      );
    case "damagePriority":
      return (
        <Screen header={header("Damage report")}
          footer={<FooterBar onCall={callSupport}><Button title="Download evidence pack" icon="upload" kind="outline" /></FooterBar>}>
          <HStack gap={12} style={{ paddingTop: 14 }}>
            <Badge text="Priority" tone="wait" icon="eye" />
            <T k="caption">{`Ref #${d?.ref ?? "WH-20915"}`}</T>
          </HStack>
          <TitleBlock top={16} title="We’ll call you within 1 hour" subtitle="A real person from our team will go through this with you." />
          <VStack style={outlined(16)}>
            <ListRow icon="shield" title={`${o?.captain?.name ?? "Raju"} is paused from new jobs`} chevron={false} />
            <Divider />
            <ListRow icon="doc" title="Evidence pack ready" subtitle="Time-stamped photos, location and call log" chevron={false} />
            <Divider />
            <ListRow icon="rupee" title="We help with the claim" subtitle="Small damage paid from our protection fund" chevron={false} />
          </VStack>
        </Screen>
      );
    default:
      return (
        <Screen header={header("Report sent")} footer={<FooterBar onCall={callSupport}><Button title="Done" onClick={() => router.popToRoot()} /></FooterBar>}>
          <HStack gap={12} style={{ paddingTop: 14 }}>
            <Badge text="Under review" tone="wait" icon="eye" />
            <T k="caption">{`Ref #${d?.ref ?? "WH-20914"}`}</T>
          </HStack>
          <TitleBlock top={16} title="We’re checking the photos" subtitle={`${Fmt.rupees(o?.price ?? 149)} stays on hold. You’ll hear from us within 24 hours.`} />
          <StatusSteps spacing={22} current={1} steps={[
            { title: "Report received", detail: Fmt.time(d?.createdAt ?? new Date()) },
            { title: "Comparing photos", detail: "Your photos vs the captain’s before and after" },
            { title: "Decision", detail: "By 9:00 AM tomorrow" },
          ]} />
        </Screen>
      );
  }
}

// MARK: C37 Refund status

export function RefundScreen() {
  const { store, router } = useApp();
  const o = store.currentOrder;
  const r = o?.refund;
  const started = r?.startedAt ?? new Date();
  return (
    <Screen header={<AppBar title="Refund" onLeading={() => router.pop()} onTrailing={() => router.push({ n: "help" })} style={{ padding: "4px 14px 0" }} />}
      footer={<FooterBar onCall={callSupport}><Button title="Done" onClick={() => router.pop()} /></FooterBar>}>
      <TD k="label" style={{ paddingTop: 18 }}>Refund amount</TD>
      <TD k="bigMoney" mono style={{ paddingTop: 2 }}>{Fmt.rupees(r?.amount ?? 149)}</TD>
      <HStack gap={8} style={{ padding: "0 12px", height: 30, borderRadius: 999, background: C.successTint, marginTop: 10, marginBottom: 22 }}>
        <Icon name="rupee" size={13} color={C.onSuccess} />
        <T k="label" c={C.onSuccess}>{r?.credited ? "Refund done" : "Refund started"}</T>
      </HStack>
      {awaitingUPI(r) && (
        <Banner tone="wait" icon="rupee" title="We need your UPI ID." text="Refunds go to UPI only for now. Add yours and we’ll send it right away."
          actionTitle="Add UPI ID" onAction={() => { if (o) router.push({ n: "refundUPI", id: o.id }); }} style={{ marginBottom: 22 }} />
      )}
      <StatusSteps spacing={22} current={r?.credited ? 3 : awaitingUPI(r) ? 0 : 1} steps={[
        { title: "Refund started", detail: `${Fmt.date(started)} · ${Fmt.time(started)}` },
        { title: "With your bank", detail: "Usually 2 to 3 working days" },
        { title: "In your account", detail: r?.method ?? "Google Pay · ananya@okhdfc" },
      ]} />
      <TD k="caption" style={{ paddingTop: 28 }}>{`Bank reference: ${r?.bankRef ?? "RZP8812093"}. Not received by ${Fmt.date(addDays(new Date(), 4))}? Call us.`}</TD>
    </Screen>
  );
}
