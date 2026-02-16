import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const bookmarks = await prisma.bookmark.findMany({ where: { userId }, orderBy: { createdAt: "desc" } });
  return NextResponse.json(bookmarks);
}

export async function POST(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { book, chapter } = await req.json();
  const existing = await prisma.bookmark.findUnique({ where: { userId_book_chapter: { userId, book, chapter } } });
  if (existing) {
    await prisma.bookmark.delete({ where: { id: existing.id } });
    return NextResponse.json({ removed: true });
  }
  const bookmark = await prisma.bookmark.create({ data: { userId, book, chapter } });
  return NextResponse.json(bookmark);
}
