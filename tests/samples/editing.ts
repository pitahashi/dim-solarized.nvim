interface Note {
  title: string;
  archived: boolean;
}

// Keep routine identifiers quiet; types and calls provide structure.
export function visibleTitles(notes: readonly Note[]): string[] {
  const label = "Recent notes";
  console.log(label);
  return notes.filter((note) => !note.archived).map((note) => note.title);
}
