interface Note {
  title: string;
  archived: boolean;
}

const LIMIT = 10;
const ratio = 1.5;
const enabled = true;

// Keep routine identifiers quiet; types and calls provide structure.
export function visibleTitles(notes: readonly Note[]): string[] {
  const label = "Recent notes";
  if (!enabled || notes.length * ratio > LIMIT) return [];
  console.log(label);
  return notes.filter((note) => !note.archived).map((note) => note.title);
}
