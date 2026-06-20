import { defaultConfig, type GameConfig } from "./core/config.js";
import { SwingDetector } from "./core/swingDetector.js";
import { Scene3D } from "./render3d/scene3d.js";
import { HandCamera } from "./input/handCamera.js";

/**
 * 埋め込み可能な台パン神経衰弱（3D, Web Component）。
 * `<table-bang-game></table-bang-game>` を置くだけ。three.js + cannon-es でカードが物理で跳ねてめくれる。
 * 入力: ポインタの下方向フリック＝台パン。「📷 カメラで台パン」でスマホ/PCのカメラ＋手検出（実際の手で台パン）。
 */
export class TableBangGameElement extends HTMLElement {
  private readonly config: GameConfig = { ...defaultConfig };
  private detector = new SwingDetector(this.config);
  private scene: Scene3D | null = null;
  private resizeObserver: ResizeObserver | null = null;
  private handCamera: HandCamera | null = null;
  private cameraOn = false;

  connectedCallback(): void {
    const root = this.attachShadow({ mode: "open" });
    root.innerHTML = `
      <style>
        :host { display:block; position:relative; width:100%; height:100%; min-height:380px; touch-action:none; user-select:none; }
        video { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; border-radius:12px; display:none; background:#000; }
        canvas { position:absolute; inset:0; width:100%; height:100%; border-radius:12px; }
        .hud { position:absolute; inset:0; pointer-events:none; font:600 14px system-ui,sans-serif; color:#fff; }
        .top { position:absolute; top:8px; left:10px; right:10px; display:flex; justify-content:space-between; align-items:flex-start; }
        .badge { background:rgba(0,0,0,.45); padding:4px 10px; border-radius:999px; }
        .cam { pointer-events:auto; cursor:pointer; border:0; font:600 13px system-ui; color:#fff;
          background:rgba(0,0,0,.5); padding:6px 12px; border-radius:999px; }
        .cam.on { background:#16a34a; }
        .hint { position:absolute; bottom:8px; left:0; right:0; text-align:center; opacity:.85; font-size:12px; padding:0 8px; }
        .overlay { position:absolute; inset:0; display:none; flex-direction:column; align-items:center; justify-content:center;
          gap:14px; background:rgba(0,0,0,.55); pointer-events:auto; }
        .overlay h2 { font-size:30px; margin:0; }
        button.retry { font:600 15px system-ui; padding:10px 22px; border:0; border-radius:999px; background:#f59e0b; color:#111; cursor:pointer; }
      </style>
      <video id="cam" playsinline muted></video>
      <canvas></canvas>
      <div class="hud">
        <div class="top">
          <span class="badge" id="turns">0 ターン</span>
          <button class="cam" id="camBtn">📷 カメラで台パン</button>
          <span class="badge" id="score">0</span>
        </div>
        <div class="hint" id="hint">下方向にすばやくフリック＝台パン（速いほど広く飛ぶ）</div>
      </div>
      <div class="overlay" id="overlay">
        <h2>クリア！</h2>
        <div class="badge" id="resultDetail"></div>
        <button class="retry" id="retry">もう一度あそぶ</button>
      </div>
    `;
    const canvas = root.querySelector("canvas") as HTMLCanvasElement;
    this.scene = new Scene3D(this, canvas, this.config);
    this.scene.onUpdate = () => this.syncHud();

    root.getElementById("retry")!.addEventListener("click", () => this.restart());
    root.getElementById("camBtn")!.addEventListener("click", () => void this.toggleCamera());
    canvas.addEventListener("pointermove", this.onPointer);
    canvas.addEventListener("pointerdown", this.onPointer);
    canvas.addEventListener("pointerleave", () => this.detector.lost());

    this.resizeObserver = new ResizeObserver(() => this.scene?.resize());
    this.resizeObserver.observe(this);

    this.scene.start();
    this.syncHud();
  }

  disconnectedCallback(): void {
    this.resizeObserver?.disconnect();
    this.handCamera?.stop();
    this.scene?.dispose();
  }

  private restart(): void {
    (this.shadowRoot!.getElementById("overlay") as HTMLElement).style.display = "none";
    this.detector.lost();
    this.scene?.retry();
    this.syncHud();
  }

  private async toggleCamera(): Promise<void> {
    const root = this.shadowRoot!;
    const btn = root.getElementById("camBtn") as HTMLButtonElement;
    const video = root.getElementById("cam") as HTMLVideoElement;
    const hint = root.getElementById("hint") as HTMLElement;

    if (this.cameraOn) {
      this.handCamera?.stop();
      this.cameraOn = false;
      video.style.display = "none";
      this.scene?.setCameraBackground(false);
      btn.classList.remove("on");
      btn.textContent = "📷 カメラで台パン";
      hint.textContent = "下方向にすばやくフリック＝台パン（速いほど広く飛ぶ）";
      return;
    }

    btn.textContent = "起動中…";
    btn.disabled = true;
    try {
      this.handCamera ??= new HandCamera();
      await this.handCamera.start(video, {
        onSample: (x, y, t) => {
          const punch = this.detector.process({ x, y, timestamp: t });
          if (punch) {
            this.scene?.bangAtPointer(punch.x, punch.y, punch.peakVelocity);
            if (this.scene?.state.isCleared) this.showResult();
          }
        },
        onLost: () => this.detector.lost(),
      });
      this.cameraOn = true;
      video.style.display = "block";
      this.scene?.setCameraBackground(true);
      btn.classList.add("on");
      btn.textContent = "📷 カメラOFF";
      hint.textContent = "カメラに手を写して振り下ろす＝台パン";
    } catch (err) {
      hint.textContent = `カメラを使えませんでした（${err instanceof Error ? err.message : "不明"}）。https かカメラ許可を確認してください`;
      btn.textContent = "📷 カメラで台パン";
    } finally {
      btn.disabled = false;
    }
  }

  private onPointer = (e: PointerEvent): void => {
    if (!this.scene) return;
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    const y = (e.clientY - rect.top) / rect.height;
    const punch = this.detector.process({ x, y, timestamp: e.timeStamp / 1000 });
    if (punch) {
      this.scene.bangAtPointer(punch.x, punch.y, punch.peakVelocity);
      if (this.scene.state.isCleared) this.showResult();
    }
  };

  private showResult(): void {
    const s = this.scene!.state;
    const root = this.shadowRoot!;
    (root.getElementById("overlay") as HTMLElement).style.display = "flex";
    root.getElementById("resultDetail")!.textContent = `${s.turns} ターン / スコア ${s.score}`;
  }

  private syncHud(): void {
    if (!this.scene) return;
    const root = this.shadowRoot!;
    root.getElementById("turns")!.textContent = `${this.scene.state.turns} ターン`;
    root.getElementById("score")!.textContent = `${this.scene.state.score}`;
    if (this.scene.state.isCleared) this.showResult();
  }
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
