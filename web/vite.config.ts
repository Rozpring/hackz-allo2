import { defineConfig } from "vite";

// ライブラリビルド: <table-bang-game> Web Component を単一ファイルへ。
// `npm run dev` ではデモ（index.html）が起動する。
export default defineConfig({
  build: {
    lib: {
      entry: "src/index.ts",
      name: "TableBang",
      fileName: () => "table-bang.js",
      formats: ["es"],
    },
  },
});
