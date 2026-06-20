/** ペア判定に必要な最小契約。`matchKey` が一致する2枚がペア（同ランク＋同色）。 */
export interface MatchableCard {
  readonly matchKey: number;
  readonly isFaceUp: boolean;
}

/**
 * 表になっているカードを走査し、同一 `matchKey` が2枚揃う組をすべて返す（複数同時可）。
 * 相手が表に揃わないカードは含めない。各キーは構成上2枚を超えないが安全のため先頭2枚に限定。
 */
export function findPairs<C extends MatchableCard>(faceUp: C[]): C[][] {
  const groups = new Map<number, C[]>();
  for (const card of faceUp) {
    if (!card.isFaceUp) continue;
    const arr = groups.get(card.matchKey) ?? [];
    arr.push(card);
    groups.set(card.matchKey, arr);
  }
  const pairs: C[][] = [];
  for (const arr of groups.values()) {
    if (arr.length >= 2) pairs.push(arr.slice(0, 2));
  }
  return pairs;
}
