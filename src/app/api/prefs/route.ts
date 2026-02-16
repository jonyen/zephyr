import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const prefs = await prisma.userPrefs.findUnique({ where: { userId } });
  return NextResponse.json(prefs ?? { lastBook: "Genesis", lastChapter: 1 });
}

export async function PUT(req: Request) {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { lastBook, lastChapter } = await req.json();
  const prefs = await prisma.userPrefs.upsert({
    where: { userId },
    update: { lastBook, lastChapter },
    create: { userId, lastBook, lastChapter },
  });
  return NextResponse.json(prefs);
}
