import { describe, it, expect } from "vitest";
import { makeStandardDeck, matchKey } from "./deck.js";
import { findPairs } from "./matchEvaluator.js";
import { powerFromPeakVelocity } from "./powerCalculator.js";
import { radiusForPower, falloff } from "./shockwave.js";
import { defaultConfig } from "./config.js";
import { GameState } from "./gameState.js";
import { SwingDetector } from "./swingDetector.js";
import { Game } from "./game.js";

describe("deck", () => {
  it("standard deck has 52 cards", () => {
    expect(makeStandardDeck(false).length).toBe(52);
  });
  it("each matchKey has exactly 2 cards (26 pairs, same rank+color)", () => {
    const counts = new Map<number, number>();
    for (const c of makeStandardDeck(false)) {
      const k = matchKey(c.rank, c.suit);
      counts.set(k, (counts.get(k) ?? 0) + 1);
    }
    expect(counts.size).toBe(26);
    expect([...counts.values()].every((v) => v === 2)).toBe(true);
  });
  it("A♠ and A♣ pair; A♠ and A♥ do not", () => {
    expect(matchKey(0, "spades")).toBe(matchKey(0, "clubs"));
    expect(matchKey(0, "spades")).not.toBe(matchKey(0, "hearts"));
  });
});

describe("matchEvaluator", () => {
  it("detects multiple simultaneous pairs, ignores lone/face-down", () => {
    const cards = [
      { matchKey: 1, isFaceUp: true },
      { matchKey: 1, isFaceUp: true },
      { matchKey: 2, isFaceUp: true },
      { matchKey: 2, isFaceUp: true },
      { matchKey: 3, isFaceUp: true },
      { matchKey: 4, isFaceUp: false },
    ];
    expect(findPairs(cards).length).toBe(2);
  });
});

describe("powerCalculator", () => {
  it("clamps and increases monotonically", () => {
    const c = defaultConfig;
    expect(powerFromPeakVelocity(c.swingVelocityThreshold - 1, c)).toBe(c.minPower);
    expect(powerFromPeakVelocity(c.velocityForMaxPower + 10, c)).toBe(c.maxPower);
    expect(powerFromPeakVelocity(3, c)).toBeGreaterThan(powerFromPeakVelocity(2, c));
  });
});

describe("shockwave", () => {
  it("radius increases with power, clamped", () => {
    const c = defaultConfig;
    expect(radiusForPower(0, c)).toBeCloseTo(c.radiusForMinPower);
    expect(radiusForPower(1, c)).toBeCloseTo(c.radiusForMaxPower);
    expect(radiusForPower(0.5, c)).toBeGreaterThan(radiusForPower(0, c));
  });
  it("falloff is 1 at center, 0 at/after radius", () => {
    expect(falloff(0, 0.2)).toBeCloseTo(1);
    expect(falloff(0.2, 0.2)).toBeCloseTo(0);
    expect(falloff(0.5, 0.2)).toBe(0);
    expect(falloff(0.1, 0.2)).toBeCloseTo(0.5);
  });
});

describe("gameState (turn-based)", () => {
  it("counts turns, scores combo, clears at zero pairs", () => {
    const s = new GameState(defaultConfig);
    s.startPlaying(8);
    s.incrementTurn();
    expect(s.turns).toBe(1);
    s.onPairsMatched(2, 6); // combo x: 2*100*1.5 = 300
    expect(s.score).toBe(300);
    expect(s.combo).toBe(2);
    s.onPairsMatched(1, 0);
    expect(s.phase).toBe("clear");
  });
  it("ignores turns/score after clear", () => {
    const s = new GameState(defaultConfig);
    s.startPlaying(1);
    s.onPairsMatched(1, 0);
    s.incrementTurn();
    s.onPairsMatched(2, 0);
    expect(s.turns).toBe(0);
    expect(s.score).toBe(100);
  });
});

describe("swingDetector", () => {
  const dt = 0.05;
  function feed(d: SwingDetector, descend = 6, delta = 0.12, stop = 8) {
    let t = 0;
    let y = 0.1;
    let event = null as ReturnType<SwingDetector["process"]>;
    for (let i = 0; i < descend; i++) {
      event = d.process({ x: 0.5, y, timestamp: t }) ?? event;
      t += dt;
      y += delta;
    }
    for (let i = 0; i < stop; i++) {
      event = d.process({ x: 0.5, y, timestamp: t }) ?? event;
      t += dt;
    }
    return event;
  }
  it("detects punch on fast descend then stop", () => {
    const e = feed(new SwingDetector(defaultConfig));
    expect(e).not.toBeNull();
    expect(e!.peakVelocity).toBeGreaterThanOrEqual(defaultConfig.swingVelocityThreshold);
  });
  it("does not trigger on slow movement", () => {
    const e = feed(new SwingDetector(defaultConfig), 6, 0.004, 8);
    expect(e).toBeNull();
  });
  it("finalizes on detection gap during swing", () => {
    const d = new SwingDetector(defaultConfig);
    let t = 0;
    let y = 0.1;
    for (let i = 0; i < 6; i++) {
      d.process({ x: 0.5, y, timestamp: t });
      t += dt;
      y += 0.12;
    }
    const e = d.process({ x: 0.5, y, timestamp: t + defaultConfig.maxSampleGap + 0.1 });
    expect(e).not.toBeNull();
  });
});

describe("Game (full flow)", () => {
  it("builds 52 cards and starts playing", () => {
    const g = new Game();
    g.start();
    expect(g.cards.length).toBe(52);
    expect(g.state.phase).toBe("playing");
    expect(g.remainingPairs()).toBe(26);
  });
  it("a strong bang flips cards and counts a turn", () => {
    // 決定的 rng（常に 0）で falloff>0 のカードを必ずめくる
    const g = new Game(defaultConfig, () => 0);
    g.start();
    const before = g.cards.filter((c) => c.facing === "up").length;
    g.bang({ x: 0.5, y: 0.5 }, defaultConfig.velocityForMaxPower);
    const after = g.cards.filter((c) => c.facing !== "down").length;
    expect(g.state.turns).toBe(1);
    expect(after).toBeGreaterThan(before);
  });
});
