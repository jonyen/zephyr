import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const entries = await prisma.historyEntry.findMany({
    where: { userId }, orderBy: { visitedAt: "desc" }, take: 100,
  });
  return NextResponse.json(entries);
}

export async function POST(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { book, chapter, verseStart, verseEnd } = await req.json();
  const entry = await prisma.historyEntry.create({
    data: { userId, book, chapter, verseStart: verseStart ?? null, verseEnd: verseEnd ?? null },
  });
  return NextResponse.json(entry);
}

export async function DELETE() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  await prisma.historyEntry.deleteMany({ where: { userId } });
  return NextResponse.json({ ok: true });
}
