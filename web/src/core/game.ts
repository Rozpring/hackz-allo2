import { defaultConfig, type GameConfig } from "./config.js";
import { makeStandardDeck, matchKey, type DeckCard, type Suit } from "./deck.js";
import { GameState } from "./gameState.js";
import { findPairs } from "./matchEvaluator.js";
import { powerFromPeakVelocity } from "./powerCalculator.js";
import { falloff, radiusForPower } from "./shockwave.js";

export type CardFacing = "down" | "up" | "collected";

/** 盤面上の1枚。座標は盤面正規化 [0,1]×[0,1]。 */
export interface BoardCard {
  readonly id: number;
  readonly rank: number;
  readonly suit: Suit;
  readonly matchKey: number;
  readonly col: number;
  readonly row: number;
  /** 盤面正規化座標 (0..1)。 */
  readonly x: number;
  readonly y: number;
  facing: CardFacing;
}

export interface BangResult {
  /** めくれた（反転した）カード id。 */
  flipped: number[];
  /** 成立して回収されたペア（card id の組）。 */
  matched: number[][];
  power: number;
}

/**
 * 台パン1回のフローを束ねる Web 版オーケストレータ（Swift: CardManager + ShockwaveSystem + GameSession 相当）。
 * bang(point, peakVelocity) → 威力算出 → 半径内カードを距離減衰確率でめくる → 同色ペア回収・加点。
 */
export class Game {
  readonly cards: BoardCard[] = [];
  readonly state: GameState;
  private rows = 0;

  constructor(
    private readonly config: GameConfig = defaultConfig,
    private readonly rng: () => number = Math.random,
  ) {
    this.state = new GameState(config);
  }

  /** デッキを生成し格子配置（全伏せ）してプレイ開始。 */
  start(): void {
    this.cards.length = 0;
    const deck: DeckCard[] = makeStandardDeck(true, this.rng);
    const cols = this.config.gridColumns;
    this.rows = Math.ceil(deck.length / cols);
    deck.forEach((card, i) => {
      const col = i % cols;
      const row = Math.floor(i / cols);
      this.cards.push({
        id: i,
        rank: card.rank,
        suit: card.suit,
        matchKey: matchKey(card.rank, card.suit),
        col,
        row,
        x: cols > 1 ? col / (cols - 1) : 0.5,
        y: this.rows > 1 ? row / (this.rows - 1) : 0.5,
        facing: "down",
      });
    });
    this.state.startPlaying(this.remainingPairs());
  }

  get gridRows(): number {
    return this.rows;
  }

  /** 台パン: 着地点(盤面正規化)とピーク速度から威力を出し、半径内カードを距離減衰確率でめくる→ペア回収。 */
  bang(point: { x: number; y: number }, peakVelocity: number): BangResult {
    const power = powerFromPeakVelocity(peakVelocity, this.config);
    this.state.recordPower(power);
    this.state.incrementTurn();

    const radius = radiusForPower(power, this.config);
    const flipped: number[] = [];
    for (const card of this.cards) {
      if (card.facing === "collected") continue;
      const dist = Math.hypot(card.x - point.x, card.y - point.y);
      const chance = falloff(dist, radius) * this.config.flipChanceGain;
      if (chance > 0 && this.rng() < chance) {
        card.facing = card.facing === "up" ? "down" : "up"; // 物理由来の反転（表↔伏せ）
        flipped.push(card.id);
      }
    }

    const matched = this.collectMatches();
    return { flipped, matched, power };
  }

  /** 表の同色ランクペアを回収・加点して、回収した id 組を返す。 */
  private collectMatches(): number[][] {
    const faceUp = this.cards.filter((c) => c.facing === "up");
    const pairs = findPairs(
      faceUp.map((c) => ({ matchKey: c.matchKey, isFaceUp: true, ref: c })),
    );
    const matchedIds: number[][] = [];
    for (const pair of pairs) {
      for (const p of pair) p.ref.facing = "collected";
      matchedIds.push(pair.map((p) => p.ref.id));
    }
    this.state.onPairsMatched(matchedIds.length, this.remainingPairs());
    return matchedIds;
  }

  remainingPairs(): number {
    return this.cards.filter((c) => c.facing !== "collected").length >> 1;
  }

  retry(): void {
    this.state.retry();
    this.start();
  }
}
