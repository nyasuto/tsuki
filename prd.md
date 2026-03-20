# PRD: µCC — Small C to Wasm Compiler in MoonBit
**プロジェクト名**: Tsuki（月 — MoonBit にちなむ）  
**言語**: MoonBit  
**出力ターゲット**: WebAssembly (Wasm)  
**開発手法**: Ralph Loop（Claude Code + moonbit-practice プラグイン）  
**主目的**: MoonBit + Ralph Loop の開発体験評価  
**ステータス**: Draft v1.0  
**作成日**: 2026-03-20

---

## 1. プロジェクト概要

### 1.1 何を作るか

C 言語のサブセット（Small C: 変数・関数・ポインタ・構造体）を受け取り、実行可能な WebAssembly バイナリを出力するコンパイラを MoonBit で実装する。

### 1.2 何を検証するか

このプロジェクトの真の目的は、以下の仮説の検証である。

- **仮説 1**: MoonBit の秒単位のコンパイルは、Ralph Loop のイテレーション効率を Go と比較して体感可能なレベルで向上させるか。
- **仮説 2**: moonbit-practice プラグインにより、Claude Code は MoonBit の訓練データ不足を実用レベルで克服できるか。
- **仮説 3**: MoonBit のパターンマッチングと代数的データ型は、コンパイラの AST 操作において Go の構造体 + switch よりも自然に書けるか。
- **仮説 4**: MoonBit → Wasm の出力パスにおいて、「MoonBit で書いたコンパイラが Wasm を吐く」という入れ子構造は実際に機能するか。

### 1.3 計測項目

各フェーズ完了時に以下を記録し、Go プロジェクト（gf-claude-quota 等）との比較に備える。

| 計測項目 | 方法 |
|---|---|
| フェーズあたりの所要時間 | 開始・終了の wall clock |
| Ralph Loop のイテレーション回数 | tasks.md への記録 |
| moon check / moon test のエラー→修正の平均サイクル | JSONL ログから集計 |
| Claude Code が生成した MoonBit コードの初回コンパイル通過率 | 手動記録 |
| 人間の介入回数と内容 | tasks.md に都度メモ |

### 1.4 スコープ外

- プリプロセッサ（#include, #define）
- 浮動小数点型
- 可変長引数
- 標準ライブラリの完全実装
- 最適化パス（定数畳み込み等は任意拡張）
- セルフホスティング

---

## 2. C 言語サブセット仕様

### 2.1 サポートする型

```c
int             // 32-bit 整数 → Wasm i32
char            // 8-bit → Wasm i32 として扱う
void            // 戻り値なし
T*              // ポインタ → Wasm i32（線形メモリアドレス）
struct { ... }  // 構造体 → 線形メモリ上のレイアウト
T[]             // 配列（ポインタとして扱う）
```

### 2.2 サポートする構文

```
プログラム     = (関数定義 | グローバル変数宣言 | 構造体定義)*
関数定義       = 型 識別子 '(' パラメータリスト ')' ブロック
ブロック       = '{' 文* '}'
文             = 変数宣言 | 代入 | if | while | for | return | 式文 | ブロック
式             = 整数リテラル | 文字リテラル | 文字列リテラル
               | 識別子 | 二項演算 | 単項演算 | 関数呼び出し
               | 配列添字 | メンバアクセス | ポインタ演算
               | sizeof | キャスト
二項演算子     = + - * / % == != < > <= >= && || & | ^ << >>
単項演算子     = - ! ~ * & ++ --
```

### 2.3 テスト用 C プログラム例

```c
// Phase 2 完了時点で動くべきプログラム
int add(int a, int b) {
    return a + b;
}

int main() {
    int x = add(3, 4);
    return x;  // → 7
}

// Phase 4 完了時点で動くべきプログラム
struct Point {
    int x;
    int y;
};

int distance_squared(struct Point* p1, struct Point* p2) {
    int dx = p2->x - p1->x;
    int dy = p2->y - p1->y;
    return dx * dx + dy * dy;
}

int main() {
    struct Point a;
    a.x = 3;
    a.y = 0;
    struct Point b;
    b.x = 0;
    b.y = 4;
    return distance_squared(&a, &b);  // → 25
}
```

---

## 3. アーキテクチャ

### 3.1 コンパイルパイプライン

```
C ソースコード
    │
    ▼
┌──────────┐
│  Lexer   │  文字列 → Token 列
└──────────┘
    │
    ▼
┌──────────┐
│  Parser  │  Token 列 → AST
└──────────┘
    │
    ▼
┌──────────┐
│  Sema    │  AST → 型付き AST（型チェック・シンボル解決）
└──────────┘
    │
    ▼
┌──────────┐
│  Codegen │  型付き AST → Wasm バイナリ（WAT テキスト or バイナリ直接）
└──────────┘
    │
    ▼
.wasm ファイル
```

### 3.2 MoonBit の強みが活きるポイント

| コンパイラ要素 | MoonBit の活用 |
|---|---|
| Token 定義 | `enum Token { Plus; Minus; IntLit(Int); Ident(String); ... }` |
| AST 定義 | 代数的データ型による再帰的な木構造 |
| パターンマッチ | 各コンパイラパスでの AST ノード分岐 |
| エラー処理 | `Result` 型 + 静的エラー伝搬チェック |
| Wasm 出力 | `Bytes` / `Buffer` によるバイナリ生成 |
| テスト | `inspect` ベースのスナップショットテスト |

### 3.3 Wasm 出力戦略

Wasm バイナリを直接生成する（WAT テキスト経由ではなく）。理由は以下のとおり。

- 外部ツール（wat2wasm）への依存を排除
- MoonBit の `Bytes` / `FixedArray[Byte]` でバイナリエンコーディングを直接制御
- LEB128 エンコーディング等を自前実装することで教育的価値も得られる
- 出力 .wasm を `wasmtime` や `node --experimental-wasm` で直接実行検証

### 3.4 メモリモデル

Wasm の線形メモリ（1ページ = 64KB）上に以下を配置する。

```
┌─────────────────────────────────────┐
│ 0x0000: 静的データ（文字列リテラル等）  │
├─────────────────────────────────────┤
│ グローバル変数領域                    │
├─────────────────────────────────────┤
│ ↓ ヒープ（malloc 用、Phase 5 で実装）│
│                                     │
│ ↑ スタック（ローカル変数・引数）       │
├─────────────────────────────────────┤
│ 0xFFFF: スタックベース               │
└─────────────────────────────────────┘
```

ポインタは i32 のメモリアドレスとして表現する。Wasm の `i32.load` / `i32.store` 命令で読み書きする。

---

## 4. フェーズ設計

各フェーズは Ralph Loop の1〜3セッションで完了する粒度に設計する。
各フェーズ末尾に必ず「動く状態」を作り、テストで検証する。

### Phase 1: プロジェクト基盤 + Lexer（目安: 1日）

**ゴール**: C ソースコードを Token 列に変換できる。

**タスク**:
- MoonBit プロジェクト初期化（`moon new mucc`）
- CLAUDE.md に MoonBit 開発ルール・moonbit-practice 参照指示を配置
- Token 型の定義（enum）
- Lexer の実装（キーワード・演算子・リテラル・識別子）
- スナップショットテスト: `"int main() { return 42; }"` → Token 列

**完了条件**:
- `moon check` がエラーなしで通る
- `moon test` で Lexer のスナップショットテストが全て通る

**計測**: Claude Code の MoonBit enum 生成精度、初回コンパイル通過率

---

### Phase 2: Parser + 基本 Codegen（目安: 2-3日）

**ゴール**: 整数リテラルの return と四則演算、関数定義・呼び出しが Wasm にコンパイルできる。

**タスク**:
- AST 型の定義（代数的データ型）
- 再帰下降パーサーの実装
  - プログラム → 関数定義の列
  - 文 → return 文、変数宣言、代入、式文
  - 式 → 整数リテラル、二項演算（優先順位付き）、関数呼び出し
- Wasm バイナリエンコーダの基盤
  - LEB128 エンコーディング
  - Wasm モジュール構造（type section, function section, code section, export section）
- Codegen: AST → Wasm 命令列
  - `i32.const`, `i32.add`, `i32.sub`, `i32.mul`, `i32.div_s`
  - `call`, `return`
  - ローカル変数 → Wasm locals
- テスト用ランナー（生成した .wasm を wasmtime で実行して終了コードを検証）

**完了条件**:
- `int main() { return 42; }` → `.wasm` → wasmtime で実行 → 終了コード 42
- `int add(int a, int b) { return a + b; } int main() { return add(3, 4); }` → 7

**計測**: パーサーの再帰下降パターンでの Claude Code の自律性

---

### Phase 3: 制御フロー + 比較演算（目安: 2日）

**ゴール**: if/else, while, for ループが動く。

**タスク**:
- パーサー拡張: if/else 文、while 文、for 文
- 比較演算子・論理演算子の Codegen
- Wasm 制御フロー命令の生成
  - `if` → `block` + `br_if`
  - `while` → `loop` + `br_if` + `br`
  - `for` → while への変換
- 短絡評価（`&&`, `||`）

**完了条件**:
```c
// フィボナッチ（ループ版）
int fib(int n) {
    int a = 0;
    int b = 1;
    for (int i = 0; i < n; i++) {
        int tmp = a + b;
        a = b;
        b = tmp;
    }
    return a;
}
int main() { return fib(10); }  // → 55
```

---

### Phase 4: ポインタ + 構造体（目安: 3日）

**ゴール**: ポインタ演算と構造体が動く。

**タスク**:
- 意味解析（Sema）パスの導入
  - シンボルテーブル（スコープチェイン）
  - 型チェック
  - 構造体のフィールドオフセット計算
- 線形メモリ上のメモリレイアウト
  - スタックフレーム管理（SP レジスタ = Wasm global）
  - `&` 演算 → ローカル変数のスタックアドレス
  - `*` 演算 → `i32.load` / `i32.store`
  - `->` 演算 → ベースアドレス + オフセット + load
- sizeof 演算子

**完了条件**:
- `distance_squared` テスト（2.3 節の例）が動く
- ポインタ経由の値の読み書きが正しい

**計測**: Sema パスの複雑さに対する Claude Code の対処能力（ここが最も人間介入が増えると予想）

---

### Phase 5: 配列 + 文字列 + 簡易 malloc（目安: 2日）

**ゴール**: 配列アクセスと文字列リテラルが動く。

**タスク**:
- 配列宣言と添字アクセス（ポインタ演算への変換）
- 文字列リテラル → 線形メモリの静的データセクション
- 簡易 malloc（バンプアロケータ）
  - Wasm memory.grow を活用
- Wasm data section への文字列埋め込み

**完了条件**:
```c
int sum(int* arr, int len) {
    int total = 0;
    for (int i = 0; i < len; i++) {
        total = total + arr[i];
    }
    return total;
}
```

---

### Phase 6: 仕上げ + 評価レポート（目安: 1日）

**ゴール**: プロジェクトの知見を文書化する。

**タスク**:
- エラーメッセージの改善（行番号・カラム番号の表示）
- エッジケースの修正
- README.md の作成
- 開発体験評価レポートの作成
  - 仮説 1〜4 に対する結論
  - Go プロジェクトとの比較所感
  - Ralph Loop × MoonBit の tips/落とし穴
  - moonbit-practice プラグインの有効性評価

---

## 5. Ralph Loop 運用設計

### 5.1 ファイル構成

```
mucc/
├── CLAUDE.md          # Claude Code 設定（MoonBit ルール + moonbit-practice 参照）
├── PROMPT.md          # Ralph Loop 用プロンプト
├── tasks.md           # タスク管理 + 計測ログ
├── src/
│   ├── lib/
│   │   ├── lexer/     # Phase 1
│   │   ├── ast/       # Phase 2
│   │   ├── parser/    # Phase 2
│   │   ├── sema/      # Phase 4
│   │   ├── codegen/   # Phase 2〜
│   │   └── wasm/      # Wasm バイナリエンコーダ
│   └── main/
│       └── main.mbt   # CLI エントリポイント
├── tests/
│   ├── fixtures/      # テスト用 .c ファイル
│   └── expected/      # 期待される実行結果
├── moon.mod.json
└── moon.pkg.json
```

### 5.2 CLAUDE.md テンプレート

```markdown
# µCC — Small C to Wasm Compiler

## MoonBit 開発ルール
- moonbit-practice プラグインのスキルを参照してコードを書くこと
- `moon check` と `moon test` を必ず実行し、エラーがあれば自律的に修正すること
- テストは inspect ベースのスナップショットテストを優先すること
- AST 型は代数的データ型（enum）で定義し、パターンマッチを活用すること
- エラーは Result 型で伝搬し、panic は使わないこと

## ビルド・テストコマンド
- `moon check` — 型チェック
- `moon test` — ユニットテスト
- `moon build --target native` — ネイティブバイナリビルド
- `moon run src/main --target native -- input.c -o output.wasm` — コンパイル実行
- `wasmtime output.wasm` — 生成された Wasm の実行

## アーキテクチャ
C ソース → Lexer → Parser → Sema → Codegen → .wasm バイナリ

## コード規約
- 各コンパイラパスは独立したパッケージに分離する
- パッケージ間の依存は一方向（lexer ← parser ← sema ← codegen）
- 公開 API は最小限にし、内部実装は隠蔽する
```

### 5.3 PROMPT.md テンプレート

```markdown
あなたは MoonBit で Small C コンパイラ（µCC）を開発するエンジニアです。

## 手順
1. tasks.md を読み、現在のタスクを確認する
2. 現在のタスクを実装する
3. `moon check` を実行し、エラーがあれば修正する
4. `moon test` を実行し、失敗があれば修正する
5. 統合テスト（.c → .wasm → wasmtime 実行）があるフェーズでは、それも実行する
6. 完了したら tasks.md のステータスを更新する
7. 次のタスクに進む

## 制約
- moonbit-practice プラグインの reference を参照して MoonBit のベストプラクティスに従う
- パターンマッチの網羅性を常に意識する（`_` のワイルドカードは最後の手段）
- Wasm バイナリは外部ツール非依存で直接生成する（wat2wasm は使わない）
- 分からないことがあれば `moon doc` や MoonBit 公式ドキュメントを参照する
```

---

## 6. リスクと軽減策

| リスク | 影響 | 軽減策 |
|---|---|---|
| MoonBit の Wasm バイナリ操作 API の不足 | Codegen が書きにくい | `Bytes` / `Buffer` で低レベル操作。不足分は FFI で補完 |
| Claude Code の MoonBit 構文エラー頻発 | イテレーション効率の低下 | moonbit-practice プラグイン + CLAUDE.md でコンテキスト強化。エラー率が高すぎる場合はスキル文書を自前で補強 |
| Wasm 線形メモリ管理の複雑さ | Phase 4 で停滞 | バンプアロケータで簡素化。GC や free は実装しない |
| MoonBit の Breaking Change | ビルドが突然壊れる | moon のバージョンを固定。`moon upgrade` は意図的にのみ実行 |
| Ralph Loop のセッション間でのコンテキスト喪失 | 手戻りの発生 | tasks.md に各フェーズの設計判断を記録。AST 型定義を早期に安定させる |

---

## 7. 成功基準

### 最小成功（Must）
- Phase 3 まで完了し、フィボナッチの Wasm 実行が動く
- 開発体験の定性的な評価が書ける

### 目標成功（Should）
- Phase 5 まで完了し、ポインタ・構造体・配列が動く
- Go プロジェクトとの比較データが取れている

### 理想成功（Could）
- Phase 6 まで完了し、評価レポートが公開可能な品質
- 知見が今後の MoonBit プロジェクト（GoForge の MoonBit 移植等）に活かせる

---

## 8. プロジェクト名について

コードネーム **Tsuki**（月）は MoonBit の Moon に由来する。
リポジトリ名は `tsuki-cc` を想定。