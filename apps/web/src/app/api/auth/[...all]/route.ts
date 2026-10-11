import { createAuth } from "@/lib/auth";

async function handleAuthRequest(request: Request) {
  return createAuth().handler(request);
}

export const GET = handleAuthRequest;
export const POST = handleAuthRequest;
