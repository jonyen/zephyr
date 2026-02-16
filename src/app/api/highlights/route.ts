import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { searchParams } = new URL(req.url);
  const book = searchParams.get("book");
  const chapter = searchParams.get("chapter");
  const where: Record<string, unknown> = { userId };
  if (book) where.book = book;
  if (chapter) where.chapter = parseInt(chapter, 10);
  const highlights = await prisma.highlight.findMany({ where, orderBy: { createdAt: "desc" } });
  return NextResponse.json(highlights);
}

export async function POST(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { book, chapter, verse, startChar, endChar, color } = await req.json();
  const highlight = await prisma.highlight.create({ data: { userId, book, chapter, verse, startChar, endChar, color } });
  return NextResponse.json(highlight);
}
