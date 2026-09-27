const LABELS: Record<number, string> = { 1: '1st', 2: '2nd', 3: '3rd' }

/** "1st", "2nd", "3rd": how a pick's rank reads on Home and the Person view. */
export const rankLabel = (rank: number) => LABELS[rank] ?? `${rank}th`
