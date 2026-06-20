/** トランプのスート（色でペア判定）。 */
export type Suit = "spades" | "hearts" | "diamonds" | "clubs";

export const allSuits: readonly Suit[] = ["spades", "hearts", "diamonds", "clubs"];

export const suitSymbol: Record<Suit, string> = {
  spades: "♠",
  hearts: "♥",
  diamonds: "♦",
  clubs: "♣",
};

export const isRed = (suit: Suit): boolean => suit === "hearts" || suit === "diamonds";

export const rankCount = 13;
export const rankLabels = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

export const rankLabel = (rank: number): string => rankLabels[Math.min(Math.max(rank, 0), rankLabels.length - 1)];

/** ペア判定キー: 同ランク＋同色で一致（A♠↔A♣, A♥↔A♦）。各キーちょうど2枚（26ペア）。 */
export const matchKey = (rank: number, suit: Suit): number => rank * 2 + (isRed(suit) ? 1 : 0);

export interface DeckCard {
  readonly rank: number;
  readonly suit: Suit;
}

/** 標準52枚デッキ（13ランク×4スート）。`shuffled` 既定 true。 */
export function makeStandardDeck(shuffled = true, rng: () => number = Math.random): DeckCard[] {
  const deck: DeckCard[] = [];
  for (const suit of allSuits) {
    for (let rank = 0; rank < rankCount; rank++) deck.push({ rank, suit });
  }
  if (!shuffled) return deck;
  // Fisher–Yates
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}
