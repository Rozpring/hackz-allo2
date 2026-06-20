// 公開API: 埋め込み用 Web Component とマウント関数、再利用可能な純ロジック。
export {
  TableBangGameElement,
  registerTableBangGame,
  mountTableBangGame,
} from "./component.js";

export { Scene3D } from "./render3d/scene3d.js";
export { Game } from "./core/game.js";
export type { BoardCard, BangResult, CardFacing } from "./core/game.js";
export { GameState } from "./core/gameState.js";
export type { GamePhase } from "./core/gameState.js";
export { defaultConfig } from "./core/config.js";
export type { GameConfig } from "./core/config.js";
export { SwingDetector } from "./core/swingDetector.js";
export type { SwingSample, PunchEvent } from "./core/swingDetector.js";
export { makeStandardDeck, matchKey, suitSymbol, rankLabel } from "./core/deck.js";
export type { DeckCard, Suit } from "./core/deck.js";

import { registerTableBangGame } from "./component.js";
// import 時に自動登録（<table-bang-game> をそのまま使えるように）。
registerTableBangGame();
