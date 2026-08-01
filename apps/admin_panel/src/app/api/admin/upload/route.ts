import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";

/** Upload a file to the clothing-assets storage bucket (service role). */
export async function POST(request: Request) {
  const supabase = getSupabaseAdmin();
  const form = await request.formData();
  const file = form.get("file");
  const path = form.get("path");

  if (!(file instanceof File) || typeof path !== "string" || !path.trim()) {
    return NextResponse.json(
      { error: "file and path are required" },
      { status: 400 },
    );
  }

  const bytes = Buffer.from(await file.arrayBuffer());
  const { data, error } = await supabase.storage
    .from("clothing-assets")
    .upload(path, bytes, {
      upsert: true,
      contentType: file.type || "image/png",
    });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  const { data: urlData } = supabase.storage
    .from("clothing-assets")
    .getPublicUrl(data.path);

  return NextResponse.json({ path: data.path, publicUrl: urlData.publicUrl });
}
