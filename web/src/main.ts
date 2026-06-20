import { mountTableBangGame } from "./index.js";

// デモ: #app にゲームをマウント。実アプリでは <table-bang-game> を置くだけでも可。
const app = document.getElementById("app");
if (app) mountTableBangGame(app);
