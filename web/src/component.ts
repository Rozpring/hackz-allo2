import { defaultConfig, type GameConfig } from "./core/config.js";
import { Game } from "./core/game.js";
import { rankLabel, suitSymbol, isRed } from "./core/deck.js";
import { SwingDetector } from "./core/swingDetector.js";

/**
 * 埋め込み可能な台パン神経衰弱（Web Component）。
 * 使い方: `<table-bang-game></table-bang-game>` を置くだけ。フレームワーク非依存。
 * 入力: ポインタ（マウス/タッチ）の下方向フリック＝台パン。速いほど高威力。
 */
export class TableBangGameElement extends HTMLElement {
  private game = new Game(this.readConfig());
  private detector = new SwingDetector(this.readConfig());
  private canvas!: HTMLCanvasElement;
  private ctx!: CanvasRenderingContext2D;
  private raf = 0;
  private flash: { x: number; y: number; r: number; t: number } | null = null;

  connectedCallback(): void {
    const root = this.attachShadow({ mode: "open" });
    root.innerHTML = `
      <style>
        :host { display:block; position:relative; width:100%; height:100%; min-height:360px; touch-action:none; user-select:none; }
        canvas { display:block; width:100%; height:100%; background:#14532d; border-radius:12px; }
        .hud { position:absolute; inset:0; pointer-events:none; font:600 14px system-ui,sans-serif; color:#fff; }
        .top { position:absolute; top:8px; left:10px; right:10px; display:flex; justify-content:space-between; }
        .badge { background:rgba(0,0,0,.35); padding:4px 10px; border-radius:999px; }
        .overlay { position:absolute; inset:0; display:none; flex-direction:column; align-items:center; justify-content:center;
          gap:14px; background:rgba(0,0,0,.55); pointer-events:auto; }
        .overlay h2 { font-size:28px; margin:0; }
        button { font:600 15px system-ui; padding:10px 22px; border:0; border-radius:999px; background:#f59e0b; color:#111; cursor:pointer; }
        .hint { position:absolute; bottom:8px; left:0; right:0; text-align:center; opacity:.8; font-size:12px; }
      </style>
      <canvas></canvas>
      <div class="hud">
        <div class="top"><span class="badge" id="turns">0 ターン</span><span class="badge" id="score">0</span></div>
        <div class="hint">下方向にすばやくフリック＝台パン（速いほど強い）</div>
      </div>
      <div class="overlay" id="overlay">
        <h2 id="result">クリア！</h2>
        <div class="badge" id="resultDetail"></div>
        <button id="retry">もう一度あそぶ</button>
      </div>
    `;
    this.canvas = root.querySelector("canvas")!;
    this.ctx = this.canvas.getContext("2d")!;
    root.getElementById("retry")!.addEventListener("click", () => this.restart());
    this.canvas.addEventListener("pointermove", this.onPointer);
    this.canvas.addEventListener("pointerdown", this.onPointer);
    this.canvas.addEventListener("pointerleave", () => this.detector.lost());

    this.game.start();
    const loop = () => {
      this.render();
      this.raf = requestAnimationFrame(loop);
    };
    loop();
  }

  disconnectedCallback(): void {
    cancelAnimationFrame(this.raf);
  }

  private readConfig(): GameConfig {
    return { ...defaultConfig };
  }

  private restart(): void {
    (this.shadowRoot!.getElementById("overlay") as HTMLElement).style.display = "none";
    this.detector.lost();
    this.game.retry();
  }

  private onPointer = (e: PointerEvent): void => {
    const rect = this.canvas.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    const y = (e.clientY - rect.top) / rect.height;
    const punch = this.detector.process({ x, y, timestamp: e.timeStamp / 1000 });
    if (punch && this.game.state.isPlaying) {
      this.game.bang({ x: punch.x, y: punch.y }, punch.peakVelocity);
      this.flash = { x: punch.x, y: punch.y, r: 0, t: 1 };
      if (this.game.state.isCleared) this.showResult();
    }
  };

  private showResult(): void {
    const root = this.shadowRoot!;
    (root.getElementById("overlay") as HTMLElement).style.display = "flex";
    root.getElementById("resultDetail")!.textContent =
      `${this.game.state.turns} ターン / スコア ${this.game.state.score}`;
  }

  private render(): void {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = this.canvas.clientWidth;
    const h = this.canvas.clientHeight;
    if (this.canvas.width !== Math.round(w * dpr) || this.canvas.height !== Math.round(h * dpr)) {
      this.canvas.width = Math.round(w * dpr);
      this.canvas.height = Math.round(h * dpr);
    }
    const ctx = this.ctx;
    ctx.save();
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = "#14532d";
    ctx.fillRect(0, 0, w, h);

    const cols = defaultConfig.gridColumns;
    const rows = this.game.gridRows;
    const pad = 16;
    const cellW = (w - pad * 2) / cols;
    const cellH = (h - pad * 2) / rows;
    const cardW = cellW * 0.84;
    const cardH = cellH * 0.84;

    for (const card of this.game.cards) {
      if (card.facing === "collected") continue;
      const cx = pad + (card.col + 0.5) * cellW;
      const cy = pad + (card.row + 0.5) * cellH;
      const x = cx - cardW / 2;
      const y = cy - cardH / 2;
      roundRect(ctx, x, y, cardW, cardH, 6);
      if (card.facing === "up") {
        ctx.fillStyle = "#fff";
        ctx.fill();
        ctx.fillStyle = isRed(card.suit) ? "#dc2626" : "#111";
        ctx.font = `bold ${Math.floor(cardH * 0.34)}px system-ui`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(`${rankLabel(card.rank)}${suitSymbol[card.suit]}`, cx, cy);
      } else {
        ctx.fillStyle = "#1e3a8a";
        ctx.fill();
        ctx.strokeStyle = "rgba(255,255,255,.5)";
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }
    }

    // 台パンの波紋
    if (this.flash) {
      const f = this.flash;
      f.r += 6;
      f.t -= 0.04;
      if (f.t <= 0) {
        this.flash = null;
      } else {
        ctx.strokeStyle = `rgba(245,158,11,${f.t})`;
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(pad + f.x * (w - pad * 2), pad + f.y * (h - pad * 2), f.r, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
    ctx.restore();

    const root = this.shadowRoot!;
    root.getElementById("turns")!.textContent = `${this.game.state.turns} ターン`;
    root.getElementById("score")!.textContent = `${this.game.state.score}`;
  }
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

let registered = false;

/** カスタム要素 `<table-bang-game>` を登録する（多重呼び出し安全）。 */
export function registerTableBangGame(tag = "table-bang-game"): void {
  if (registered || customElements.get(tag)) {
    registered = true;
    return;
  }
  customElements.define(tag, TableBangGameElement);
  registered = true;
}

/** 任意の要素配下にゲームをマウントする（フレームワーク非依存の埋め込み口）。 */
export function mountTableBangGame(container: HTMLElement): TableBangGameElement {
  registerTableBangGame();
  const el = document.createElement("table-bang-game") as TableBangGameElement;
  container.appendChild(el);
  return el;
}
