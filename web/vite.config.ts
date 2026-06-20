import { defineConfig } from "vite";
import basicSsl from "@vitejs/plugin-basic-ssl";

// ライブラリビルド: <table-bang-game> Web Component を単一ファイルへ。
// dev は https（カメラ getUserMedia がセキュアコンテキスト必須のため）。
// スマホ実機は `npm run dev:phone` → https://<PCのLAN IP>:5173 を開く（証明書警告は許可）。
export default defineConfig({
  // basicSsl() が自己署名証明書を注入し https を有効化する（server.https は手動指定しない＝競合回避）。
  plugins: [basicSsl()],
  server: { host: true },
  build: {
    lib: {
      entry: "src/index.ts",
      name: "TableBang",
      fileName: () => "table-bang.js",
      formats: ["es"],
    },
  },
});
