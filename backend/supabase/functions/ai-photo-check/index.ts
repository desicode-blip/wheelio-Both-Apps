// AI photo check (roadmap: "AI photo verification").
//
// Two uses:
//  * mode "after_photos" — right after the washer uploads after-photos (W36):
//    compare before vs after per angle and flag missed spots, so the washer
//    can fix them before leaving.
//  * mode "dispute" — when a customer reports a problem (C31/C32): compare the
//    customer's photos with the washer's before and after photos and draft a
//    recommendation for the human reviewer. The final decision stays with a person.
//
// Secrets: ANTHROPIC_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
// Deploy: supabase functions deploy ai-photo-check

import Anthropic from "npm:@anthropic-ai/sdk";
import { z } from "npm:zod";
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = "claude-opus-5-5";

const AngleResult = z.object({
  angle: z.string(),
  same_vehicle: z.boolean(),
  looks_clean: z.boolean(),
  missed_spots: z.array(z.string()),
  new_damage_visible: z.boolean(),
  notes: z.string(),
});

const CheckResult = z.object({
  overall: z.enum(["pass", "fix_needed", "needs_human"]),
  angles: z.array(AngleResult),
  // Dispute mode only: which side the evidence supports, for the reviewer.
  dispute_recommendation: z.enum(["uphold", "reject", "unclear", "not_applicable"]),
  summary_for_customer: z.string(),
  summary_for_washer: z.string(),
});

// JSON Schema mirror of CheckResult for structured outputs.
const checkResultSchema = {
  type: "object",
  additionalProperties: false,
  required: ["overall", "angles", "dispute_recommendation", "summary_for_customer", "summary_for_washer"],
  properties: {
    overall: { type: "string", enum: ["pass", "fix_needed", "needs_human"] },
    angles: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["angle", "same_vehicle", "looks_clean", "missed_spots", "new_damage_visible", "notes"],
        properties: {
          angle: { type: "string" },
          same_vehicle: { type: "boolean" },
          looks_clean: { type: "boolean" },
          missed_spots: { type: "array", items: { type: "string" } },
          new_damage_visible: { type: "boolean" },
          notes: { type: "string" },
        },
      },
    },
    dispute_recommendation: { type: "string", enum: ["uphold", "reject", "unclear", "not_applicable"] },
    summary_for_customer: { type: "string" },
    summary_for_washer: { type: "string" },
  },
};

const SYSTEM = `You check photos for Wheelio, a doorstep exterior car and bike wash in India.
The wash is water and cloth only (no soap, no foam), exterior only. Interior dirt is out of scope.
You receive time-stamped photos from fixed angles. "before" and "after" photos are taken by the washer
and are the official wash evidence. "customer" photos are taken by the vehicle owner when they report a problem.

Judge only what is visible. Rain spots, old scratches and dents that already appear in the before-photo are
not the washer's fault. Water streaks, dust left on panels, unwiped mirrors and missed wheels are.
If a photo is too dark, blurred or shows a different vehicle, say so and use "needs_human".
Write summaries in plain, short English; the washer summary must be simple enough to translate to Hindi or Telugu.`;

type Photo = { role: "before" | "after" | "dispute"; angle: string; storage_path: string; taken_at: string };

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const { order_id, mode } = await req.json() as { order_id: string; mode: "after_photos" | "dispute" };

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: photos, error } = await supabase
    .from("order_photos")
    .select("role, angle, storage_path, taken_at")
    .eq("order_id", order_id)
    .in("role", mode === "dispute" ? ["before", "after", "dispute"] : ["before", "after"])
    .order("angle");
  if (error) return Response.json({ error: error.message }, { status: 500 });

  // Signed URLs keep the bucket private; Claude fetches each image by URL.
  const content: Anthropic.Beta.BetaContentBlockParam[] = [];
  for (const p of (photos ?? []) as Photo[]) {
    const { data: signed } = await supabase.storage.from("order-photos").createSignedUrl(p.storage_path, 600);
    if (!signed) continue;
    content.push({ type: "text", text: `${p.role} photo · angle: ${p.angle} · taken ${p.taken_at}` });
    content.push({ type: "image", source: { type: "url", url: signed.signedUrl } });
  }
  if (mode === "dispute") {
    const { data: dispute } = await supabase.from("disputes").select("kind, note").eq("order_id", order_id)
      .order("created_at", { ascending: false }).limit(1).single();
    content.push({ type: "text", text: `Customer reported: ${dispute?.kind ?? "unknown"}. Their note: ${dispute?.note ?? ""}` });
  }
  content.push({
    type: "text",
    text: mode === "dispute"
      ? "Compare the customer's photos with the washer's before and after photos and recommend a decision."
      : "Compare each before/after pair. List missed spots the washer should fix before leaving.",
  });

  const client = new Anthropic();
  const response = await client.beta.messages.create({
    model: MODEL,
    max_tokens: 16000,
    system: SYSTEM,
    // Photo evidence decides who gets paid, so think it through.
    output_config: { effort: "high", format: { type: "json_schema", schema: checkResultSchema } },
    // If the request is declined by a safety classifier, the API retries on a fallback model.
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    messages: [{ role: "user", content }],
  });

  if (response.stop_reason === "refusal") {
    // Never auto-decide; hand it to a person.
    await save(supabase, order_id, mode, { overall: "needs_human", reason: "model_refused" });
    return Response.json({ overall: "needs_human" });
  }

  const text = response.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
  const parsed = CheckResult.safeParse(JSON.parse(text));
  if (!parsed.success) {
    await save(supabase, order_id, mode, { overall: "needs_human", reason: "unparseable" });
    return Response.json({ overall: "needs_human" });
  }

  await save(supabase, order_id, mode, parsed.data);
  return Response.json(parsed.data);
});

async function save(
  supabase: ReturnType<typeof createClient>,
  orderId: string,
  mode: string,
  result: Record<string, unknown>,
) {
  if (mode === "dispute") {
    await supabase.from("disputes").update({ ai_summary: result }).eq("order_id", orderId).eq("outcome", "under_review");
  } else {
    await supabase.from("order_photos").update({ ai_check: result }).eq("order_id", orderId).eq("role", "after");
  }
  await supabase.from("order_events").insert({ order_id: orderId, kind: `ai_check_${mode}`, data: result });
}
