# µCC (Tsuki) — Task Tracker

> Ralph Loop 用タスク管理ファイル
> 各タスクの `[ ]` を `[x]` に変更して進捗を記録する
> ループの終了判定はスクリプト側で自動的に行うため、完了マーカーの追記は不要

---

## Phase 1: プロジェクト基盤 + Lexer — 🔄 IN_PROGRESS

### セットアップ
- [x] `moon new mucc` でプロジェクト初期化
- [x] ディレクトリ構成を作成（src/lib/lexer, src/lib/ast, src/lib/parser, src/lib/sema, src/lib/codegen, src/lib/wasm, src/main）
- [x] 各パッケージの moon.pkg.json を作成
- [x] CLAUDE.md をプロジェクトルートに配置

### Lexer 実装
- [x] Token 型を enum で定義（キーワード: int, char, void, struct, if, else, while, for, return, sizeof）
- [x] Token 型に演算子を追加（+, -, *, /, %, ==, !=, <, >, <=, >=, &&, ||, &, |, ^, <<, >>, !, ~, ++, --）
- [x] Token 型に区切り記号を追加（(, ), {, }, [, ], ;, ,, ., ->）
- [x] Token 型にリテラルと識別子を追加（IntLit, CharLit, StringLit, Ident）
- [x] Lexer の基本構造を実装（入力文字列、位置管理、peek/advance）
- [x] 整数リテラルのスキャン
- [x] 文字列リテラル・文字リテラルのスキャン（エスケープシーケンス: \n, \t, \\, \0）
- [x] 識別子とキーワードのスキャン（キーワードテーブルとの照合）
- [x] 演算子と区切り記号のスキャン（1文字・2文字演算子の区別: = vs ==, & vs &&）
- [x] ホワイトスペースとコメント（// と /* */）のスキップ
- [ ] Lexer のスナップショットテスト: `"int main() { return 42; }"`
- [ ] Lexer のスナップショットテスト: `"int add(int a, int b) { return a + b; }"`
- [ ] Lexer のスナップショットテスト: エッジケース（文字列中のエスケープ、連続演算子）

### Phase 1 完了条件
- [ ] `moon check` エラーなし
- [ ] `moon test` 全テスト通過

**完了日時**:  
**特記事項**:  

---

## Phase 2: Parser + 基本 Codegen — ⏳ WAITING

### AST 定義
- [ ] 式（Expr）の enum 定義: IntLit, CharLit, StringLit, Ident, BinaryOp, UnaryOp, Call, Assign
- [ ] 文（Stmt）の enum 定義: Return, VarDecl, ExprStmt, Block, If, While, For
- [ ] トップレベル（TopLevel）の enum 定義: FuncDef, GlobalVarDecl
- [ ] 型（CType）の enum 定義: Int, Char, Void, Ptr(CType), Struct(String), Array(CType, Int)
- [ ] Program 型の定義: TopLevel のリスト

### Parser 実装
- [ ] Parser の基本構造（Token 列、位置管理、expect/peek/advance）
- [ ] 式のパース: プラット法または再帰下降で優先順位を処理
- [ ] 一次式: 整数リテラル、識別子、括弧式、関数呼び出し
- [ ] 単項演算: -, !, ~, *, &
- [ ] 二項演算: 算術 → 比較 → 論理の優先順位チェイン
- [ ] 文のパース: return, 変数宣言（int x = expr;）, 代入, 式文, ブロック
- [ ] 関数定義のパース: 戻り値型 + 名前 + パラメータリスト + ブロック
- [ ] プログラム全体のパース: 関数定義の列
- [ ] Parser のスナップショットテスト: `"int main() { return 42; }"` → AST

### Wasm バイナリエンコーダ
- [ ] LEB128（unsigned / signed）エンコーディング実装 + テスト
- [ ] Wasm モジュールヘッダ（magic number + version）
- [ ] Section エンコーディングの汎用関数（section id + size + payload）
- [ ] Type Section: 関数シグネチャ（param types → result types）
- [ ] Function Section: 関数インデックス → type インデックスのマッピング
- [ ] Memory Section: 線形メモリの宣言（initial 1 page）
- [ ] Export Section: main 関数と memory のエクスポート
- [ ] Code Section: 関数本体（locals + 命令列）

### Codegen 実装
- [ ] 式の Codegen: IntLit → `i32.const`, BinaryOp → 対応する `i32.xxx` 命令
- [ ] ローカル変数: Wasm locals へのマッピング（変数名 → local index）
- [ ] 関数呼び出し: `call` 命令（関数名 → function index）
- [ ] return 文: Codegen + `end`
- [ ] 変数宣言と代入: `local.set` / `local.get`
- [ ] 複数関数のコンパイル: function index の管理
- [ ] .wasm バイナリファイルへの書き出し

### Phase 2 統合テスト
- [ ] `int main() { return 42; }` → .wasm → wasmtime → exit code 42
- [ ] `int main() { return 3 + 4 * 5; }` → 23
- [ ] `int add(int a, int b) { return a + b; } int main() { return add(3, 4); }` → 7
- [ ] `int main() { int x = 10; int y = 20; return x + y; }` → 30

### Phase 2 完了条件
- [ ] `moon check` エラーなし
- [ ] `moon test` 全テスト通過
- [ ] 上記の統合テスト全て通過

**完了日時**:  
**特記事項**:  

---

## Phase 3: 制御フロー + 比較演算 — ⏳ WAITING

### Parser 拡張
- [ ] if / else 文のパース
- [ ] while 文のパース
- [ ] for 文のパース（init; cond; update の3要素）
- [ ] 比較演算子（==, !=, <, >, <=, >=）の AST ノード確認
- [ ] 論理演算子（&&, ||）の AST ノード確認

### Codegen 拡張
- [ ] 比較演算: `i32.eq`, `i32.ne`, `i32.lt_s`, `i32.gt_s`, `i32.le_s`, `i32.ge_s`
- [ ] if/else → Wasm `if ... else ... end` ブロック
- [ ] while → Wasm `block` + `loop` + `br_if` + `br`
- [ ] for → while への AST レベル変換（desugar）
- [ ] 短絡評価: && → if(lhs, rhs, 0), || → if(lhs, 1, rhs) パターン
- [ ] ビット演算: `i32.and`, `i32.or`, `i32.xor`, `i32.shl`, `i32.shr_s`
- [ ] 前置 ++/-- および後置 ++/-- の Codegen

### Phase 3 統合テスト
- [ ] if/else: `int abs(int x) { if (x < 0) return -x; else return x; }` → abs(-5) == 5
- [ ] while ループ: 階乗計算 `fact(5)` → 120
- [ ] for ループ: フィボナッチ `fib(10)` → 55
- [ ] ネストした制御フロー: ユークリッド互除法 `gcd(12, 8)` → 4

### Phase 3 完了条件
- [ ] `moon check` エラーなし
- [ ] `moon test` 全テスト通過
- [ ] 統合テスト全て通過

**完了日時**:  
**特記事項**:  

---

## Phase 4: ポインタ + 構造体 — ⏳ WAITING

### Sema（意味解析）パス導入
- [ ] シンボルテーブルの実装（スコープチェインつき: グローバル → 関数 → ブロック）
- [ ] 型チェックの基本: 代入互換性、関数の戻り値型
- [ ] 構造体定義の登録とフィールドオフセット計算（alignment 4 bytes）
- [ ] 型付き AST への変換（各 Expr ノードに解決済み型を付与）

### メモリ管理
- [ ] スタックポインタ（SP）を Wasm global として定義
- [ ] 関数プロローグ/エピローグ: SP の push/pop（フレームサイズ分）
- [ ] ローカル変数のスタック配置: Wasm locals ではなく線形メモリ上に配置
  - 注: アドレスを取る変数（`&x`）のみスタック配置。それ以外は引き続き Wasm locals でよい。

### ポインタ演算 Codegen
- [ ] `&x`（アドレス取得）→ SP + ローカルオフセット
- [ ] `*p`（間接参照）→ `i32.load` / `i32.store`（左辺値/右辺値の区別）
- [ ] ポインタ加算（`p + n`）→ ポインタ + n * sizeof(*p)
- [ ] 配列添字（`a[i]`）→ ポインタ演算への変換

### 構造体 Codegen
- [ ] 構造体変数のスタック配置（フィールドサイズの合計 + パディング）
- [ ] メンバアクセス（`s.field`）→ ベースアドレス + フィールドオフセット
- [ ] アロー演算（`p->field`）→ `*p` + フィールドオフセット
- [ ] sizeof 演算子: 型からバイトサイズを計算

### Phase 4 統合テスト
- [ ] ポインタ経由の値の読み書き: `int x = 42; int* p = &x; return *p;` → 42
- [ ] ポインタ経由の変更: `int x = 1; int* p = &x; *p = 99; return x;` → 99
- [ ] 構造体: distance_squared テスト（PRD セクション 2.3）→ 25
- [ ] 構造体のポインタ渡し: 関数に `struct Point*` を渡して値を変更

### Phase 4 完了条件
- [ ] `moon check` エラーなし
- [ ] `moon test` 全テスト通過
- [ ] 統合テスト全て通過

**完了日時**:  
**特記事項**:  

---

## Phase 5: 配列 + 文字列 + 簡易 malloc — ⏳ WAITING

### 配列
- [ ] 配列宣言のパース: `int arr[10];`
- [ ] 配列初期化のパース: `int arr[] = {1, 2, 3};`（任意。なくてもよい）
- [ ] 配列添字アクセスの Codegen（Phase 4 のポインタ演算を再利用）

### 文字列
- [ ] 文字列リテラル → Wasm data section への埋め込み
- [ ] 文字列リテラルの型: `char*`（data section 内のアドレス）
- [ ] Data Section のエンコーディング

### 簡易 malloc
- [ ] バンプアロケータの実装（Wasm global でヒープポインタ管理）
- [ ] `memory.grow` による動的メモリ拡張（必要に応じて）
- [ ] free は実装しない（バンプアロケータなので）

### Phase 5 統合テスト
- [ ] 配列の合計: `sum(int* arr, int len)` テスト
- [ ] 文字列リテラルのアドレスが正しい（data section 内を指している）
- [ ] 動的配列: malloc で確保した領域への読み書き

### Phase 5 完了条件
- [ ] `moon check` エラーなし
- [ ] `moon test` 全テスト通過
- [ ] 統合テスト全て通過

**完了日時**:  
**特記事項**:  

---

## Phase 6: 仕上げ + 評価レポート — ⏳ WAITING

### 品質改善
- [ ] エラーメッセージに行番号・カラム番号を含める
- [ ] 未定義変数・未定義関数の参照時に分かりやすいエラー
- [ ] 型ミスマッチ時のエラーメッセージ改善
- [ ] エッジケースの修正（テスト追加含む）

### ドキュメント
- [ ] README.md の作成（ビルド方法、使い方、サポートする C サブセット）
- [ ] アーキテクチャ図（コンパイルパイプライン）

### 開発体験評価レポート
- [ ] 仮説 1 の評価: MoonBit のコンパイル速度がイテレーション効率に与えた影響
- [ ] 仮説 2 の評価: moonbit-practice プラグインの有効性（初回コンパイル通過率の推移）
- [ ] 仮説 3 の評価: パターンマッチング × AST 操作の体験（Go との比較所感）
- [ ] 仮説 4 の評価: MoonBit → Wasm の入れ子構造の実用性
- [ ] Ralph Loop × MoonBit の tips と落とし穴のまとめ
- [ ] 総合所感と今後の展望

### Phase 6 完了条件
- [ ] README.md が完成している
- [ ] 評価レポートが記述されている

**完了日時**:  
**特記事項**:  

---

