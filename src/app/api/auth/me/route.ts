import { NextResponse } from "next/server";
import { getAuthUser } from "@/lib/auth";
import { prisma } from "@/lib/db";

export async function GET() {
  const userId = await getAuthUser();
  if (!userId) return NextResponse.json(null, { status: 401 });
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { id: true, email: true },
  });
  return NextResponse.json(user);
}
