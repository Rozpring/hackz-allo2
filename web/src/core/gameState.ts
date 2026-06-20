import type { GameConfig } from "./config.js";

export type GamePhase = "placing" | "playing" | "clear";

/** スコア・コンボ・ターン数・残ペア・勝敗の単一情報源（ターン制: 1ターン＝台パン1回、全ペアでクリア）。 */
export class GameState {
  score = 0;
  combo = 0;
  turns = 0;
  remainingPairs = 0;
  lastPower = 0;
  phase: GamePhase = "placing";

  constructor(private readonly config: GameConfig) {}

  get isCleared(): boolean {
    return this.phase === "clear";
  }

  get isPlaying(): boolean {
    return this.phase === "playing";
  }

  startPlaying(totalPairs: number): void {
    this.phase = "playing";
    this.turns = 0;
    this.remainingPairs = totalPairs;
    this.score = 0;
    this.combo = 0;
  }

  recordPower(power: number): void {
    this.lastPower = power;
  }

  incrementTurn(): void {
    if (this.phase !== "playing") return;
    this.turns += 1;
  }

  /** 盤面静止で成立したペア数を反映。複数同時はコンボ倍率。プレイ中のみ。 */
  onPairsMatched(pairCount: number, remainingPairs: number): void {
    if (this.phase !== "playing") return;
    this.remainingPairs = remainingPairs;
    if (pairCount <= 0) {
      this.combo = 0;
      return;
    }
    this.combo = pairCount;
    const multiplier = 1 + (pairCount - 1) * this.config.comboMultiplierStep;
    this.score += Math.round(pairCount * this.config.scorePerPair * multiplier);
    if (remainingPairs === 0) this.phase = "clear";
  }

  retry(): void {
    this.score = 0;
    this.combo = 0;
    this.turns = 0;
    this.lastPower = 0;
    this.remainingPairs = 0;
    this.phase = "placing";
  }
}
