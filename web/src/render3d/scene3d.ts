import * as THREE from "three";
import * as CANNON from "cannon-es";
import { defaultConfig, type GameConfig } from "../core/config.js";
import { makeStandardDeck, matchKey, type Suit } from "../core/deck.js";
import { GameState } from "../core/gameState.js";
import { findPairs } from "../core/matchEvaluator.js";
import { powerFromPeakVelocity } from "../core/powerCalculator.js";
import { faceTexture, backTexture } from "./cardTexture.js";

interface Card3D {
  mesh: THREE.Mesh;
  body: CANNON.Body;
  rank: number;
  suit: Suit;
  matchKey: number;
  collected: boolean;
}

// シーン単位（メートル相当・見やすさ優先のスケール）。
const CARD_W = 0.6;
const CARD_T = 0.05;
const CARD_D = 0.85;
const SPACING = 0.8;
const SETTLE_SPEED = 0.18;
const SETTLE_FRAMES = 24;
const WATCHDOG_FRAMES = 300;

// 威力→ワールド影響半径・インパルス（実機チューニング対象）。
const RADIUS_MIN = 1.2;
const RADIUS_MAX = 5.0;
const IMPULSE_SCALE = 1.1;
const UP_BIAS = 0.55;

/** three.js 描画 + cannon-es 物理で「台パンでカードが跳ねてめくれる」を再現する3Dシーン。 */
export class Scene3D {
  readonly state: GameState;
  onUpdate: (() => void) | null = null;

  private renderer: THREE.WebGLRenderer;
  private scene = new THREE.Scene();
  private camera: THREE.PerspectiveCamera;
  private world = new CANNON.World({ gravity: new CANNON.Vec3(0, -9.82, 0) });
  private cards: Card3D[] = [];
  private raf = 0;
  private readonly plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  private readonly raycaster = new THREE.Raycaster();

  private monitoring = false;
  private quietFrames = 0;
  private framesSinceBang = 0;
  private cols = defaultConfig.gridColumns;
  private rows = 0;

  constructor(
    private readonly container: HTMLElement,
    canvas: HTMLCanvasElement,
    private readonly config: GameConfig = defaultConfig,
  ) {
    this.state = new GameState(config);
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.scene.background = new THREE.Color(0x0f2e1c);

    this.camera = new THREE.PerspectiveCamera(50, 1, 0.1, 100);
    this.camera.position.set(0, 6.5, 6.2);
    this.camera.lookAt(0, 0, 0);

    this.scene.add(new THREE.AmbientLight(0xffffff, 0.85));
    const dir = new THREE.DirectionalLight(0xffffff, 1.1);
    dir.position.set(3, 8, 4);
    this.scene.add(dir);

    this.buildStaticGeometry();
  }

  start(): void {
    this.resetBoard();
    this.resize();
    if (!this.raf) this.loop();
  }

  retry(): void {
    this.state.retry();
    this.resetBoard();
  }

  dispose(): void {
    cancelAnimationFrame(this.raf);
    this.raf = 0;
    this.renderer.dispose();
  }

  /** カメラ映像を背景に透過する（AR風）か、緑の盤面背景にするか。 */
  setCameraBackground(transparent: boolean): void {
    this.scene.background = transparent ? null : new THREE.Color(0x0f2e1c);
  }

  resize(): void {
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    if (w === 0 || h === 0) return;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  /** 正規化キャンバス座標 (0..1, 左上原点) とピーク速度で台パン。 */
  bangAtPointer(nx: number, ny: number, peakVelocity: number): void {
    if (!this.state.isPlaying) return;
    const power = powerFromPeakVelocity(peakVelocity, this.config);
    this.state.recordPower(power);
    this.state.incrementTurn();

    const center = this.boardPointFromPointer(nx, ny);
    const powerNorm = clamp01((power - this.config.minPower) / Math.max(1e-6, this.config.maxPower - this.config.minPower));
    const radius = RADIUS_MIN + powerNorm * (RADIUS_MAX - RADIUS_MIN);

    for (const card of this.cards) {
      if (card.collected) continue;
      const p = card.body.position;
      const dx = p.x - center.x;
      const dz = p.z - center.z;
      const dist = Math.hypot(dx, dz);
      const fall = Math.max(0, 1 - dist / radius);
      if (fall <= 0) continue;

      card.body.wakeUp();
      const horiz = dist > 1e-4 ? new CANNON.Vec3(dx / dist, 0, dz / dist) : new CANNON.Vec3(0, 0, 0);
      const mag = power * fall * IMPULSE_SCALE + 0.05;
      const impulse = new CANNON.Vec3(
        horiz.x * mag + rand(0.04),
        (UP_BIAS + 0.3) * mag,
        horiz.z * mag + rand(0.04),
      );
      const at = new CANNON.Vec3(p.x + rand(0.05), p.y, p.z + rand(0.05));
      card.body.applyImpulse(impulse, at);
      card.body.angularVelocity.set(rand(6), rand(6), rand(6));
    }

    this.monitoring = true;
    this.quietFrames = 0;
    this.framesSinceBang = 0;
    this.onUpdate?.();
  }

  // MARK: - build

  private buildStaticGeometry(): void {
    const ground = new CANNON.Body({ type: CANNON.Body.STATIC, shape: new CANNON.Plane() });
    ground.quaternion.setFromEuler(-Math.PI / 2, 0, 0);
    this.world.addBody(ground);

    // 外周の不可視壁（盤外こぼれ防止）。
    const wallH = 2;
    const ext = 5;
    const walls: [number, number, number, number, number, number][] = [
      [ext, wallH / 2, 0, 0.2, wallH, ext * 2],
      [-ext, wallH / 2, 0, 0.2, wallH, ext * 2],
      [0, wallH / 2, ext, ext * 2, wallH, 0.2],
      [0, wallH / 2, -ext, ext * 2, wallH, 0.2],
    ];
    for (const [x, y, z, sx, sy, sz] of walls) {
      const body = new CANNON.Body({
        type: CANNON.Body.STATIC,
        shape: new CANNON.Box(new CANNON.Vec3(sx / 2, sy / 2, sz / 2)),
      });
      body.position.set(x, y, z);
      this.world.addBody(body);
    }
  }

  private resetBoard(): void {
    for (const card of this.cards) {
      this.scene.remove(card.mesh);
      card.mesh.geometry.dispose();
      this.world.removeBody(card.body);
    }
    this.cards = [];

    const deck = makeStandardDeck(true);
    this.cols = this.config.gridColumns;
    this.rows = Math.ceil(deck.length / this.cols);
    const offX = ((this.cols - 1) * SPACING) / 2;
    const offZ = ((this.rows - 1) * SPACING) / 2;

    deck.forEach((c, i) => {
      const col = i % this.cols;
      const row = Math.floor(i / this.cols);
      const x = col * SPACING - offX;
      const z = row * SPACING - offZ;
      this.cards.push(this.makeCard(c.rank, c.suit, x, z));
    });

    this.state.startPlaying(this.remainingPairs());
    this.monitoring = false;
    this.onUpdate?.();
  }

  private makeCard(rank: number, suit: Suit, x: number, z: number): Card3D {
    const white = new THREE.MeshStandardMaterial({ color: 0xf5f5f5, roughness: 0.7 });
    const face = new THREE.MeshStandardMaterial({ map: faceTexture(rank, suit), roughness: 0.6 });
    const back = new THREE.MeshStandardMaterial({ map: backTexture(), roughness: 0.6 });
    // BoxGeometry material order: [+x,-x,+y,-y,+z,-z]。表面=+Y、裏面=-Y。
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(CARD_W, CARD_T, CARD_D), [white, white, face, back, white, white]);
    this.scene.add(mesh);

    const body = new CANNON.Body({
      mass: 0.05,
      shape: new CANNON.Box(new CANNON.Vec3(CARD_W / 2, CARD_T / 2, CARD_D / 2)),
      material: new CANNON.Material({ friction: 0.4, restitution: 0.2 }),
      allowSleep: true,
      sleepSpeedLimit: 0.15,
      sleepTimeLimit: 0.4,
    });
    body.linearDamping = 0.2;
    body.angularDamping = 0.3;
    body.position.set(x, CARD_T / 2 + 0.01, z);
    // 伏せ初期姿勢: 表面(+Y)を下へ（X軸π回転）。
    body.quaternion.setFromAxisAngle(new CANNON.Vec3(1, 0, 0), Math.PI);
    this.world.addBody(body);

    return { mesh, body, rank, suit, matchKey: matchKey(rank, suit), collected: false };
  }

  // MARK: - loop / settle

  private loop = (): void => {
    this.raf = requestAnimationFrame(this.loop);
    this.world.step(1 / 60);
    for (const card of this.cards) {
      if (card.collected) continue;
      card.mesh.position.set(card.body.position.x, card.body.position.y, card.body.position.z);
      card.mesh.quaternion.set(card.body.quaternion.x, card.body.quaternion.y, card.body.quaternion.z, card.body.quaternion.w);
    }
    if (this.monitoring) this.updateSettle();
    this.renderer.render(this.scene, this.camera);
  };

  private updateSettle(): void {
    this.framesSinceBang += 1;
    let maxSpeed = 0;
    for (const card of this.cards) {
      if (card.collected) continue;
      const v = card.body.velocity;
      const a = card.body.angularVelocity;
      maxSpeed = Math.max(maxSpeed, Math.hypot(v.x, v.y, v.z), Math.hypot(a.x, a.y, a.z) * 0.2);
    }
    if (maxSpeed < SETTLE_SPEED) this.quietFrames += 1;
    else this.quietFrames = 0;

    if (this.quietFrames >= SETTLE_FRAMES || this.framesSinceBang >= WATCHDOG_FRAMES) {
      this.monitoring = false;
      this.evaluate();
    }
  }

  private evaluate(): void {
    const up = new THREE.Vector3(0, 1, 0);
    const q = new THREE.Quaternion();
    const faceUp = this.cards.filter((card) => {
      if (card.collected) return false;
      q.set(card.body.quaternion.x, card.body.quaternion.y, card.body.quaternion.z, card.body.quaternion.w);
      const worldUp = up.clone().applyQuaternion(q);
      return worldUp.y > 0;
    });

    const pairs = findPairs(faceUp.map((c) => ({ matchKey: c.matchKey, isFaceUp: true, ref: c })));
    for (const pair of pairs) {
      for (const p of pair) {
        const card = p.ref;
        card.collected = true;
        this.scene.remove(card.mesh);
        card.mesh.geometry.dispose();
        this.world.removeBody(card.body);
      }
    }
    this.state.onPairsMatched(pairs.length, this.remainingPairs());
    this.onUpdate?.();
  }

  private remainingPairs(): number {
    return this.cards.filter((c) => !c.collected).length >> 1;
  }

  private boardPointFromPointer(nx: number, ny: number): THREE.Vector3 {
    const ndc = new THREE.Vector2(nx * 2 - 1, -(ny * 2 - 1));
    this.raycaster.setFromCamera(ndc, this.camera);
    const hit = new THREE.Vector3();
    const ok = this.raycaster.ray.intersectPlane(this.plane, hit);
    return ok ? hit : new THREE.Vector3(0, 0, 0);
  }
}

function clamp01(v: number): number {
  return Math.min(Math.max(v, 0), 1);
}

function rand(scale: number): number {
  return (Math.random() * 2 - 1) * scale;
}
