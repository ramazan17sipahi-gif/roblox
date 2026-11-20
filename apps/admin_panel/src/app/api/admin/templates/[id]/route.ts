import { NextResponse, type NextRequest } from "next/server";
import { adminApiFailure } from "@/lib/admin-auth";
import { getSupabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";

/** Update a clothing template by id. */
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const failure = adminApiFailure(request);
  if (failure) return failure;
  const { id } = await params;
  const supabase = getSupabaseAdmin();

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const { data, error } = await supabase
    .from("clothing_templates")
    .update(body)
    .eq("id", id)
    .select("*")
    .maybeSingle();

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
  if (!data) {
    return NextResponse.json(
      { error: "Şablon güncellenemedi (kayıt bulunamadı veya yazma engellendi)." },
      { status: 404 },
    );
  }
  return NextResponse.json({ data });
}

/** Delete a clothing template by id. */
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const failure = adminApiFailure(request);
  if (failure) return failure;
  const { id } = await params;
  const supabase = getSupabaseAdmin();

  const { error } = await supabase.from("clothing_templates").delete().eq("id", id);
  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}
