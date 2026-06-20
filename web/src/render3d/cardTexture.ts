import * as THREE from "three";
import { rankLabel, suitSymbol, isRed, type Suit } from "../core/deck.js";

const faceCache = new Map<string, THREE.Texture>();
let backCache: THREE.Texture | null = null;

/** ランク＋スートの表面テクスチャ（キャッシュ）。 */
export function faceTexture(rank: number, suit: Suit): THREE.Texture {
  const key = `${rank}-${suit}`;
  const cached = faceCache.get(key);
  if (cached) return cached;
  const tex = makeTexture((ctx, w, h) => {
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = "rgba(0,0,0,0.18)";
    ctx.lineWidth = 6;
    roundRectPath(ctx, 8, 8, w - 16, h - 16, 18);
    ctx.stroke();

    const color = isRed(suit) ? "#dc2626" : "#111111";
    const label = rankLabel(rank);
    ctx.fillStyle = color;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.font = `bold ${Math.floor(h * 0.42)}px system-ui, sans-serif`;
    ctx.fillText(suitSymbol[suit], w / 2, h / 2 + h * 0.04);

    ctx.textAlign = "left";
    ctx.textBaseline = "top";
    ctx.font = `bold ${Math.floor(h * 0.16)}px system-ui, sans-serif`;
    ctx.fillText(label, 18, 14);
    ctx.fillText(suitSymbol[suit], 18, 14 + h * 0.16);
  });
  faceCache.set(key, tex);
  return tex;
}

/** カード裏のテクスチャ（キャッシュ）。 */
export function backTexture(): THREE.Texture {
  if (backCache) return backCache;
  backCache = makeTexture((ctx, w, h) => {
    ctx.fillStyle = "#1e3a8a";
    ctx.fillRect(0, 0, w, h);
    ctx.strokeStyle = "#ffffff";
    ctx.lineWidth = 8;
    roundRectPath(ctx, 12, 12, w - 24, h - 24, 16);
    ctx.stroke();
    ctx.strokeStyle = "rgba(255,255,255,0.28)";
    ctx.lineWidth = 3;
    for (let x = -h; x < w; x += 26) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x + h, h);
      ctx.stroke();
    }
  });
  return backCache;
}

function makeTexture(draw: (ctx: CanvasRenderingContext2D, w: number, h: number) => void): THREE.Texture {
  const w = 256;
  const h = 358;
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext("2d")!;
  draw(ctx, w, h);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

function roundRectPath(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
