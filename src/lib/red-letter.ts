let redLetterData: Record<string, Record<string, number[]>> | null = null;

async function getData(): Promise<Record<string, Record<string, number[]>>> {
  if (redLetterData) return redLetterData;
  const data = await import("@/data/red_letter_verses.json");
  redLetterData = data.default ?? data;
  return redLetterData!;
}

export async function isRedLetter(book: string, chapter: number, verse: number): Promise<boolean> {
  const data = await getData();
  const chapters = data[book];
  if (!chapters) return false;
  const verses = chapters[String(chapter)];
  if (!verses) return false;
  return verses.includes(verse);
}
