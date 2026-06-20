import { FilesetResolver, HandLandmarker } from "@mediapipe/tasks-vision";

const MP_VERSION = "0.10.18";
const WASM_CDN = `https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@${MP_VERSION}/wasm`;
const MODEL_URL =
  "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task";

// MediaPipe の手ランドマーク: 9 = 中指MCP（手のひら中心相当）。ネイティブ版と同じ代表点。
const MIDDLE_MCP = 9;

export interface HandCameraCallbacks {
  /** 手の代表点（正規化 0..1, 左上原点）。 */
  onSample: (x: number, y: number, timestampSeconds: number) => void;
  /** 手を見失った。 */
  onLost: () => void;
}

/**
 * スマホ/PC のカメラ映像から MediaPipe Hands で手を検出し、代表点を供給する。
 * 出力は `SwingDetector` の `SwingSample` にそのまま渡せる（正規化座標・下向き正）。
 *
 * 注意: `getUserMedia` はセキュアコンテキスト（https または localhost）が必須。
 * スマホ実機で LAN 越しに開く場合は https 必須（vite --https やトンネル）。
 */
export class HandCamera {
  private landmarker: HandLandmarker | null = null;
  private stream: MediaStream | null = null;
  private raf = 0;
  private running = false;
  private lastTimestamp = -1;

  /** カメラと手検出器を起動して、video へ映像を流しつつ代表点を通知し続ける。 */
  async start(video: HTMLVideoElement, callbacks: HandCameraCallbacks): Promise<void> {
    this.stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: "environment" } },
      audio: false,
    });
    video.srcObject = this.stream;
    video.muted = true;
    video.playsInline = true;
    await video.play();

    const vision = await FilesetResolver.forVisionTasks(WASM_CDN);
    this.landmarker = await HandLandmarker.createFromOptions(vision, {
      baseOptions: { modelAssetPath: MODEL_URL, delegate: "GPU" },
      runningMode: "VIDEO",
      numHands: 1,
    });

    this.running = true;
    const loop = (): void => {
      if (!this.running) return;
      this.raf = requestAnimationFrame(loop);
      const now = performance.now();
      if (now <= this.lastTimestamp) return; // detectForVideo は単調増加 timestamp 必須
      this.lastTimestamp = now;
      if (!this.landmarker || video.readyState < 2) return;

      let hand: { x: number; y: number }[] | undefined;
      try {
        hand = this.landmarker.detectForVideo(video, now).landmarks?.[0];
      } catch {
        return; // 当該フレームを破棄
      }
      const point = hand?.[MIDDLE_MCP];
      if (point) callbacks.onSample(point.x, point.y, now / 1000);
      else callbacks.onLost();
    };
    loop();
  }

  stop(): void {
    this.running = false;
    cancelAnimationFrame(this.raf);
    this.stream?.getTracks().forEach((t) => t.stop());
    this.stream = null;
    this.landmarker?.close();
    this.landmarker = null;
  }
}
