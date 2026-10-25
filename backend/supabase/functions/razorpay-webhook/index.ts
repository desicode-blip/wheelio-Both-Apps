// Razorpay webhook: payment captured / failed / refund processed.
// Payment is held by WashKrew (Razorpay Route with on-hold transfers) and
// released to the washer's linked account only after approval.
//
// Secrets: RAZORPAY_WEBHOOK_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
// Razorpay dashboard → Webhooks → URL: <project>.functions.supabase.co/razorpay-webhook
// Events: payment.captured, payment.failed, refund.processed, transfer.processed

import { createClient } from "npm:@supabase/supabase-js@2";

async function validSignature(body: string, signature: string | null, secret: string): Promise<boolean> {
  if (!signature) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  // Constant-time compare.
  if (hex.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < hex.length; i++) diff |= hex.charCodeAt(i) ^ signature.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  const body = await req.text();
  if (!(await validSignature(body, req.headers.get("x-razorpay-signature"), Deno.env.get("RAZORPAY_WEBHOOK_SECRET")!))) {
    return new Response("bad signature", { status: 401 });
  }
  const event = JSON.parse(body);
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  switch (event.event) {
    case "payment.captured": {
      const p = event.payload.payment.entity;
      const { data: payment } = await supabase.from("payments")
        .update({ status: "captured", provider_payment_id: p.id, method: p.method, raw: p, updated_at: new Date().toISOString() })
        .eq("provider_order_id", p.order_id).select("order_id").single();
      if (payment) {
        // Paid → start looking for a washer and send the WhatsApp entry-pass message.
        await supabase.from("orders").update({ status: "searching" }).eq("id", payment.order_id)
          .in("status", ["pending_payment", "payment_pending"]);
        await supabase.from("order_events").insert({ order_id: payment.order_id, kind: "paid" });
        await supabase.functions.invoke("dispatch-jobs", { body: { order_id: payment.order_id } });
        await supabase.functions.invoke("whatsapp-webhook", { body: { action: "send_booking", order_id: payment.order_id } });
      }
      break;
    }
    case "payment.failed": {
      const p = event.payload.payment.entity;
      await supabase.from("payments").update({ status: "failed", raw: p }).eq("provider_order_id", p.order_id);
      break;
    }
    case "refund.processed": {
      const r = event.payload.refund.entity;
      await supabase.from("refunds").update({ status: "processed", bank_ref: r.acquirer_data?.rrn ?? null, processed_at: new Date().toISOString() })
        .eq("provider_refund_id", r.id);
      break;
    }
    case "transfer.processed": {
      const t = event.payload.transfer.entity;
      await supabase.from("payouts").update({ status: "paid", paid_at: new Date().toISOString() }).eq("provider_transfer_id", t.id);
      break;
    }
  }
  return new Response("ok");
});
