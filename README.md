# µCC (Tsuki) — Small C to Wasm Compiler

C 言語のサブセットを WebAssembly バイナリに直接コンパイルするツール。
[MoonBit](https://www.moonbitlang.com/) で実装。外部ツール（wat2wasm 等）を使わず、.wasm バイナリを自前で生成します。

## ビルド

### 前提条件

- [MoonBit](https://www.moonbitlang.com/) (v0.1.x 以降)
- [wasmtime](https://wasmtime.dev/) (実行検証用、任意)

### コマンド

```bash
moon build --target native    # ネイティブバイナリをビルド
```

## 使い方

```bash
# C ソースを Wasm にコンパイル
moon run src/main --target native -- input.c -o out.wasm

# 生成した Wasm を実行（wasmtime）
wasmtime out.wasm
echo "exit: $?"
```

### 例

```c
// hello.c
int add(int a, int b) {
    return a + b;
}

int main() {
    return add(3, 4);
}
```

```bash
$ moon run src/main --target native -- hello.c -o hello.wasm
$ wasmtime hello.wasm; echo "exit: $?"
exit: 7
```

## サポートする C サブセット

### 型

| 型 | 説明 |
|---|---|
| `int` | 32 ビット整数（Wasm i32） |
| `char` | 8 ビット文字（i32 として扱う） |
| `void` | 戻り値なし |
| `T*` | ポインタ（i32 アドレス） |
| `T[N]` | 配列 |
| `struct` | 構造体（4 バイトアライメント） |

### 演算子

- **算術**: `+`, `-`, `*`, `/`, `%`
- **比較**: `==`, `!=`, `<`, `>`, `<=`, `>=`
- **論理**: `&&`, `||`, `!`
- **ビット**: `&`, `|`, `^`, `~`, `<<`, `>>`
- **インクリメント/デクリメント**: `++`, `--`（前置・後置）
- **ポインタ**: `*`（間接参照）, `&`（アドレス取得）, `->`, `.`
- **その他**: `sizeof`, 配列添字 `[]`, 関数呼び出し `()`

### 制御フロー

- `if` / `else`
- `while`
- `for`
- `return`

### その他の機能

- 関数定義と呼び出し（複数関数対応）
- ローカル変数・グローバル変数
- 構造体の定義、メンバアクセス（`.`）、アロー演算子（`->`）
- 文字列リテラル（data section に埋め込み）
- `malloc` によるヒープメモリ確保（バンプアロケータ）

### サポートしない機能

- プリプロセッサ（`#include`, `#define`）
- 浮動小数点型（`float`, `double`）
- `switch` / `case`
- `typedef`
- 可変長引数
- `free`（バンプアロケータのため）

## アーキテクチャ

```
C ソース → Lexer → Parser → Sema → Codegen → .wasm バイナリ
```

| パス | パッケージ | 入力 → 出力 |
|---|---|---|
| 字句解析 | `src/lib/lexer` | `String` → `Array[Token]` |
| 構文解析 | `src/lib/parser` | `Array[Token]` → `Program`（AST） |
| 意味解析 | `src/lib/sema` | `Program` → 型付き `Program` |
| コード生成 | `src/lib/codegen` | 型付き `Program` → Wasm 命令列 |
| バイナリ出力 | `src/lib/wasm` | Wasm 命令列 → `.wasm` バイナリ |

パッケージ依存は一方向: `lexer` ← `parser` ← `sema` ← `codegen`

### Wasm 生成の特徴

- LEB128 エンコーディングを自前で実装
- Wasm セクション（Type, Function, Memory, Export, Code, Data）を直接構築
- ポインタは i32（線形メモリアドレス）
- メモリレイアウト: 静的データ → グローバル → ヒープ↓ ... スタック↑

## テスト

```bash
moon check    # 型チェック
moon test     # ユニットテスト（スナップショットテスト）
```

## ライセンス

Apache-2.0
