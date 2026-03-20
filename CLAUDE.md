# µCC (Tsuki) — Small C to Wasm Compiler

C 言語のサブセットを WebAssembly バイナリにコンパイルするツール。MoonBit で実装。

## MoonBit 開発ルール

- moonbit-practice プラグインのスキルを参照してコードを書くこと
- `moon check` と `moon test` を必ず実行し、エラーがあれば自律的に修正すること
- テストは `inspect` ベースのスナップショットテストを優先すること
- AST 型は代数的データ型（`enum`）で定義し、パターンマッチを活用すること
- パターンマッチではワイルドカード `_` は最後の手段。網羅的に書くこと
- エラーは `Result` 型で伝搬し、`panic` は使わないこと
- View 型（StringView, ArrayView, BytesView）でゼロコピーを意識すること

## ビルド・テストコマンド

```bash
moon check                          # 型チェック
moon test                           # ユニットテスト実行
moon build --target native          # ネイティブバイナリビルド
moon run src/main --target native -- INPUT.c -o out.wasm  # C → Wasm コンパイル
wasmtime out.wasm ; echo "exit: $?" # 生成した Wasm の実行検証
```

## アーキテクチャ

```
C ソース → Lexer → Parser → Sema → Codegen → .wasm バイナリ
```

パッケージ依存は一方向: `lexer` ← `parser` ← `sema` ← `codegen`

## パッケージ構成

- `src/lib/lexer` — 字句解析（C ソース → Token 列）
- `src/lib/ast` — AST 型定義（Expr, Stmt, TopLevel, CType）
- `src/lib/parser` — 構文解析（Token 列 → AST）
- `src/lib/sema` — 意味解析（型チェック、シンボル解決）
- `src/lib/codegen` — コード生成（型付き AST → Wasm 命令列）
- `src/lib/wasm` — Wasm バイナリエンコーダ（LEB128, Section 構築）
- `src/main` — CLI エントリポイント

## Wasm 生成の制約

- .wasm バイナリを直接生成する（wat2wasm 等の外部ツール不使用）
- ポインタは i32（線形メモリアドレス）
- メモリレイアウト: 静的データ → グローバル → ヒープ↓ ... スタック↑

## コード規約

- 公開 API（`pub`）は最小限にする
- 各パスの入出力型を明確にする（Lexer: String → Array[Token], Parser: Array[Token] → Program, etc.）
- エラーメッセージにはソース位置情報（行・列）を含める