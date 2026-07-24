import { useEffect, useState } from 'react'
import { PrefsProvider } from './state/prefs'
import ChapterView from './components/ChapterView'
import { loadBook, loadRedLetter } from './lib/bible-data'
import type { Book } from './lib/types'

export default function App() {
  const [book, setBook] = useState<Book | null>(null)
  const [red, setRed] = useState<number[]>([])
  useEffect(() => {
    loadBook('Isaiah').then(setBook)
    loadRedLetter().then((m) => setRed(m['Isaiah']?.['40'] ?? []))
  }, [])
  if (!book) return null
  const ch = book.chapters.find((c) => c.number === 40)!
  return (
    <PrefsProvider>
      <ChapterView bookName="Isaiah" chapter={ch} showBookTitle={false} redVerses={red} highlights={[]} bookmarked={false} />
    </PrefsProvider>
  )
}
