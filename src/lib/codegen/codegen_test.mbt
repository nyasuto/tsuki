/// Codegen のスナップショットテスト

/// バイト列を16進数文字列に変換するヘルパー
fn bytes_to_hex(bytes : Array[Byte]) -> String {
  let buf = StringBuilder::new(size_hint=bytes.length() * 3)
  for i, b in bytes {
    if i > 0 {
      buf.write_char(' ')
    }
    let n = b.to_int()
    let hi = n >> 4
    let lo = n.land(0x0F)
    buf.write_char(hex_digit(hi))
    buf.write_char(hex_digit(lo))
  }
  buf.to_string()
}

fn hex_digit(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('A'.to_int() + n - 10).unsafe_to_char()
  }
}

/// テスト用の空コンテキストを作成するヘルパー
fn empty_ctx() -> CodegenContext {
  CodegenContext::new()
}

/// IntLiteral(42) → i32.const 42
test "emit_expr: int literal 42" {
  let code : Array[Byte] = []
  emit_expr(@ast.IntLiteral(42), code, empty_ctx())
  inspect(bytes_to_hex(code), content="41 2A")
}

/// IntLiteral(0) → i32.const 0
test "emit_expr: int literal 0" {
  let code : Array[Byte] = []
  emit_expr(@ast.IntLiteral(0), code, empty_ctx())
  inspect(bytes_to_hex(code), content="41 00")
}

/// IntLiteral(-1) → i32.const -1 (sleb128: 0x7F)
test "emit_expr: int literal -1" {
  let code : Array[Byte] = []
  emit_expr(@ast.IntLiteral(-1), code, empty_ctx())
  inspect(bytes_to_hex(code), content="41 7F")
}

/// IntLiteral(128) → i32.const 128 (sleb128: 0x80 0x01)
test "emit_expr: int literal 128" {
  let code : Array[Byte] = []
  emit_expr(@ast.IntLiteral(128), code, empty_ctx())
  inspect(bytes_to_hex(code), content="41 80 01")
}

/// CharLiteral('A') → i32.const 65
test "emit_expr: char literal A" {
  let code : Array[Byte] = []
  emit_expr(@ast.CharLiteral('A'), code, empty_ctx())
  inspect(bytes_to_hex(code), content="41 C1 00")
}

/// BinaryOp(Add, 3, 4) → i32.const 3; i32.const 4; i32.add
test "emit_expr: add 3 + 4" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Add, @ast.IntLiteral(3), @ast.IntLiteral(4)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 03 41 04 6A")
}

/// BinaryOp(Sub, 10, 3) → i32.const 10; i32.const 3; i32.sub
test "emit_expr: sub 10 - 3" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Sub, @ast.IntLiteral(10), @ast.IntLiteral(3)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 0A 41 03 6B")
}

/// BinaryOp(Mul, 6, 7) → i32.const 6; i32.const 7; i32.mul
test "emit_expr: mul 6 * 7" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Mul, @ast.IntLiteral(6), @ast.IntLiteral(7)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 06 41 07 6C")
}

/// BinaryOp(Div, 20, 4) → i32.const 20; i32.const 4; i32.div_s
test "emit_expr: div 20 / 4" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Div, @ast.IntLiteral(20), @ast.IntLiteral(4)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 14 41 04 6D")
}

/// BinaryOp(Mod, 17, 5) → i32.const 17; i32.const 5; i32.rem_s
test "emit_expr: mod 17 % 5" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Mod, @ast.IntLiteral(17), @ast.IntLiteral(5)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 11 41 05 6F")
}

/// ネストした式: 3 + 4 * 5 → i32.const 3; i32.const 4; i32.const 5; i32.mul; i32.add
test "emit_expr: nested 3 + (4 * 5)" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(
      Add,
      @ast.IntLiteral(3),
      @ast.BinaryOp(Mul, @ast.IntLiteral(4), @ast.IntLiteral(5)),
    ),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 03 41 04 41 05 6C 6A")
}

/// 比較演算: 3 == 4 → i32.const 3; i32.const 4; i32.eq
test "emit_expr: eq 3 == 4" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Eq, @ast.IntLiteral(3), @ast.IntLiteral(4)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 03 41 04 46")
}

/// 比較演算: 5 < 10 → i32.const 5; i32.const 10; i32.lt_s
test "emit_expr: lt 5 < 10" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Lt, @ast.IntLiteral(5), @ast.IntLiteral(10)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 05 41 0A 48")
}

/// ビット演算: 0xFF & 0x0F → i32.const 255; i32.const 15; i32.and
test "emit_expr: bitand" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(BitAnd, @ast.IntLiteral(255), @ast.IntLiteral(15)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 FF 01 41 0F 71")
}

/// ビット演算: 0xFF | 0x0F → i32.const 255; i32.const 15; i32.or
test "emit_expr: bitor" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(BitOr, @ast.IntLiteral(255), @ast.IntLiteral(15)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 FF 01 41 0F 72")
}

/// ビット演算: 0xFF ^ 0x0F → i32.const 255; i32.const 15; i32.xor
test "emit_expr: bitxor" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(BitXor, @ast.IntLiteral(255), @ast.IntLiteral(15)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 FF 01 41 0F 73")
}

/// ビット演算: 1 << 3 → i32.const 1; i32.const 3; i32.shl
test "emit_expr: shl" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Shl, @ast.IntLiteral(1), @ast.IntLiteral(3)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 01 41 03 74")
}

/// ビット演算: 16 >> 2 → i32.const 16; i32.const 2; i32.shr_s
test "emit_expr: shr" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Shr, @ast.IntLiteral(16), @ast.IntLiteral(2)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 10 41 02 75")
}

/// 単項演算: -42 → i32.const 0; i32.const 42; i32.sub
test "emit_expr: unary neg" {
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(Neg, @ast.IntLiteral(42)), code, empty_ctx())
  inspect(bytes_to_hex(code), content="41 00 41 2A 6B")
}

/// 単項演算: !1 → i32.const 1; i32.eqz
test "emit_expr: unary lognot" {
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(LogNot, @ast.IntLiteral(1)), code, empty_ctx())
  inspect(bytes_to_hex(code), content="41 01 45")
}

/// 単項演算: ~0 → i32.const 0; i32.const -1; i32.xor
test "emit_expr: unary bitnot" {
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(BitNot, @ast.IntLiteral(0)), code, empty_ctx())
  inspect(bytes_to_hex(code), content="41 00 41 7F 73")
}

// === ローカル変数テスト ===

/// CodegenContext: パラメータからコンテキスト作成
test "context: from_params" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
  )
  inspect(ctx.resolve("a"), content="Some(0)")
  inspect(ctx.resolve("b"), content="Some(1)")
  inspect(ctx.resolve("c"), content="None")
}

/// CodegenContext: add_local でローカル変数を追加
test "context: add_local" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }],
  )
  let idx = ctx.add_local("x")
  inspect(idx, content="1")
  inspect(ctx.resolve("x"), content="Some(1)")
}

/// Ident(a) → local.get 0（パラメータ a が local index 0）
test "emit_expr: ident local.get param" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
  )
  let code : Array[Byte] = []
  emit_expr(@ast.Ident("a"), code, ctx)
  // local.get 0 → 0x20 0x00
  inspect(bytes_to_hex(code), content="20 00")
}

/// Ident(b) → local.get 1（パラメータ b が local index 1）
test "emit_expr: ident local.get second param" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
  )
  let code : Array[Byte] = []
  emit_expr(@ast.Ident("b"), code, ctx)
  // local.get 1 → 0x20 0x01
  inspect(bytes_to_hex(code), content="20 01")
}

/// ローカル変数の local.get: add_local で追加した変数
test "emit_expr: ident local.get local var" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }],
  )
  let _ = ctx.add_local("x")
  let code : Array[Byte] = []
  emit_expr(@ast.Ident("x"), code, ctx)
  // local.get 1 → 0x20 0x01
  inspect(bytes_to_hex(code), content="20 01")
}

/// 式内でのローカル変数参照: a + b → local.get 0; local.get 1; i32.add
test "emit_expr: binary op with locals" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
  )
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Add, @ast.Ident("a"), @ast.Ident("b")),
    code,
    ctx,
  )
  // local.get 0; local.get 1; i32.add
  inspect(bytes_to_hex(code), content="20 00 20 01 6A")
}

/// 未定義変数の参照はエラーになる
test "emit_expr: undefined variable error" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  let result : Result[Unit, Error] = try {
    Ok(emit_expr(@ast.Ident("unknown"), code, ctx))
  } catch {
    e => Err(e)
  }
  inspect(
    result is Err(_),
    content="true",
  )
}

// === 関数呼び出しテスト ===

/// Call("add", [3, 4]) → i32.const 3; i32.const 4; call 0
test "emit_expr: call no args" {
  let functions : Map[String, Int] = { "foo": 0 }
  let ctx = CodegenContext::from_params([], functions~)
  let code : Array[Byte] = []
  emit_expr(@ast.Call("foo", []), code, ctx)
  // call 0 → 0x10 0x00
  inspect(bytes_to_hex(code), content="10 00")
}

/// Call("add", [3, 4]) → i32.const 3; i32.const 4; call 0
test "emit_expr: call with args" {
  let functions : Map[String, Int] = { "add": 0 }
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
    functions~,
  )
  let code : Array[Byte] = []
  emit_expr(
    @ast.Call("add", [@ast.IntLiteral(3), @ast.IntLiteral(4)]),
    code,
    ctx,
  )
  // i32.const 3; i32.const 4; call 0
  inspect(bytes_to_hex(code), content="41 03 41 04 10 00")
}

/// Call with function index > 0
test "emit_expr: call function index 1" {
  let functions : Map[String, Int] = { "foo": 0, "bar": 1 }
  let ctx = CodegenContext::from_params([], functions~)
  let code : Array[Byte] = []
  emit_expr(@ast.Call("bar", [@ast.IntLiteral(42)]), code, ctx)
  // i32.const 42; call 1
  inspect(bytes_to_hex(code), content="41 2A 10 01")
}

/// Call with local variable as argument: add(a, b) → local.get 0; local.get 1; call 0
test "emit_expr: call with local args" {
  let functions : Map[String, Int] = { "add": 0 }
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
    functions~,
  )
  let code : Array[Byte] = []
  emit_expr(
    @ast.Call("add", [@ast.Ident("a"), @ast.Ident("b")]),
    code,
    ctx,
  )
  // local.get 0; local.get 1; call 0
  inspect(bytes_to_hex(code), content="20 00 20 01 10 00")
}

/// Call with expression args: add(1 + 2, 3) → i32.const 1; i32.const 2; i32.add; i32.const 3; call 0
test "emit_expr: call with expr args" {
  let functions : Map[String, Int] = { "add": 0 }
  let ctx = CodegenContext::from_params([], functions~)
  let code : Array[Byte] = []
  emit_expr(
    @ast.Call(
      "add",
      [
        @ast.BinaryOp(Add, @ast.IntLiteral(1), @ast.IntLiteral(2)),
        @ast.IntLiteral(3),
      ],
    ),
    code,
    ctx,
  )
  // i32.const 1; i32.const 2; i32.add; i32.const 3; call 0
  inspect(bytes_to_hex(code), content="41 01 41 02 6A 41 03 10 00")
}

/// 未定義関数の呼び出しはエラーになる
test "emit_expr: undefined function error" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  let result : Result[Unit, Error] = try {
    Ok(emit_expr(@ast.Call("unknown", []), code, ctx))
  } catch {
    e => Err(e)
  }
  inspect(
    result is Err(_),
    content="true",
  )
}

/// 大きい function index (128以上, 2バイト ULEB128)
test "emit_expr: call large function index" {
  let functions : Map[String, Int] = { "big": 128 }
  let ctx = CodegenContext::from_params([], functions~)
  let code : Array[Byte] = []
  emit_expr(@ast.Call("big", []), code, ctx)
  // call 128 → 0x10 0x80 0x01
  inspect(bytes_to_hex(code), content="10 80 01")
}

/// emit_local_set: local.set 命令の生成
test "emit_local_set: index 0" {
  let code : Array[Byte] = []
  emit_local_set(0, code)
  // local.set 0 → 0x21 0x00
  inspect(bytes_to_hex(code), content="21 00")
}

/// emit_local_set: index 128（2バイト ULEB128）
test "emit_local_set: index 128" {
  let code : Array[Byte] = []
  emit_local_set(128, code)
  // local.set 128 → 0x21 0x80 0x01
  inspect(bytes_to_hex(code), content="21 80 01")
}

// === return 文テスト ===

/// return 42; → i32.const 42; return
test "emit_stmt: return int literal" {
  let code : Array[Byte] = []
  emit_stmt(@ast.Return(Some(@ast.IntLiteral(42))), code, empty_ctx())
  // i32.const 42; return → 0x41 0x2A 0x0F
  inspect(bytes_to_hex(code), content="41 2A 0F")
}

/// return; → return（void 関数の return）
test "emit_stmt: return void" {
  let code : Array[Byte] = []
  emit_stmt(@ast.Return(None), code, empty_ctx())
  // return → 0x0F
  inspect(bytes_to_hex(code), content="0F")
}

/// return a + b; → local.get 0; local.get 1; i32.add; return
test "emit_stmt: return with binary op" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
  )
  let code : Array[Byte] = []
  emit_stmt(
    @ast.Return(Some(@ast.BinaryOp(Add, @ast.Ident("a"), @ast.Ident("b")))),
    code,
    ctx,
  )
  // local.get 0; local.get 1; i32.add; return
  inspect(bytes_to_hex(code), content="20 00 20 01 6A 0F")
}

/// return add(3, 4); → i32.const 3; i32.const 4; call 0; return
test "emit_stmt: return with call" {
  let functions : Map[String, Int] = { "add": 0 }
  let ctx = CodegenContext::from_params([], functions~)
  let code : Array[Byte] = []
  emit_stmt(
    @ast.Return(Some(@ast.Call("add", [@ast.IntLiteral(3), @ast.IntLiteral(4)]))),
    code,
    ctx,
  )
  // i32.const 3; i32.const 4; call 0; return
  inspect(bytes_to_hex(code), content="41 03 41 04 10 00 0F")
}

/// return -x; → i32.const 0; local.get 0; i32.sub; return
test "emit_stmt: return with unary neg" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "x" }],
  )
  let code : Array[Byte] = []
  emit_stmt(
    @ast.Return(Some(@ast.UnaryOp(Neg, @ast.Ident("x")))),
    code,
    ctx,
  )
  // i32.const 0; local.get 0; i32.sub; return
  inspect(bytes_to_hex(code), content="41 00 20 00 6B 0F")
}

// === 変数宣言と代入テスト ===

/// int x = 42; → i32.const 42; local.set 0
test "emit_stmt: var decl with init" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  emit_stmt(@ast.VarDecl("int", "x", Some(@ast.IntLiteral(42))), code, ctx)
  // i32.const 42; local.set 0
  inspect(bytes_to_hex(code), content="41 2A 21 00")
  // x が local index 0 に登録されている
  inspect(ctx.resolve("x"), content="Some(0)")
}

/// int x; → 命令なし（初期化なし宣言）
test "emit_stmt: var decl without init" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  emit_stmt(@ast.VarDecl("int", "x", None), code, ctx)
  // 命令は生成されない
  inspect(bytes_to_hex(code), content="")
  // x が local index 0 に登録されている
  inspect(ctx.resolve("x"), content="Some(0)")
}

/// int x = 10; int y = 20; → 2つの変数が別々の local index に割り当てられる
test "emit_stmt: multiple var decls" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  emit_stmt(@ast.VarDecl("int", "x", Some(@ast.IntLiteral(10))), code, ctx)
  emit_stmt(@ast.VarDecl("int", "y", Some(@ast.IntLiteral(20))), code, ctx)
  // i32.const 10; local.set 0; i32.const 20; local.set 1
  inspect(bytes_to_hex(code), content="41 0A 21 00 41 14 21 01")
  inspect(ctx.resolve("x"), content="Some(0)")
  inspect(ctx.resolve("y"), content="Some(1)")
}

/// パラメータありの関数内で変数宣言: int add(int a, int b) { int sum = a + b; }
test "emit_stmt: var decl with params" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
  )
  let code : Array[Byte] = []
  emit_stmt(
    @ast.VarDecl(
      "int",
      "sum",
      Some(@ast.BinaryOp(Add, @ast.Ident("a"), @ast.Ident("b"))),
    ),
    code,
    ctx,
  )
  // local.get 0; local.get 1; i32.add; local.set 2
  inspect(bytes_to_hex(code), content="20 00 20 01 6A 21 02")
  inspect(ctx.resolve("sum"), content="Some(2)")
}

/// x = 5; → i32.const 5; local.tee 0（Assign は値を返す式）
test "emit_expr: assign" {
  let ctx = CodegenContext::new()
  let _ = ctx.add_local("x")
  let code : Array[Byte] = []
  emit_expr(@ast.Assign(@ast.Ident("x"), @ast.IntLiteral(5)), code, ctx)
  // i32.const 5; local.tee 0
  inspect(bytes_to_hex(code), content="41 05 22 00")
}

/// 未定義変数への代入はエラー
test "emit_expr: assign undefined variable error" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  let result : Result[Unit, Error] = try {
    Ok(emit_expr(@ast.Assign(@ast.Ident("x"), @ast.IntLiteral(5)), code, ctx))
  } catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

/// ExprStmt: 式文は結果を drop する
test "emit_stmt: expr stmt" {
  let ctx = CodegenContext::new()
  let _ = ctx.add_local("x")
  let code : Array[Byte] = []
  emit_stmt(
    @ast.ExprStmt(@ast.Assign(@ast.Ident("x"), @ast.IntLiteral(5))),
    code,
    ctx,
  )
  // i32.const 5; local.tee 0; drop
  inspect(bytes_to_hex(code), content="41 05 22 00 1A")
}

/// Block: 複数の文を順に実行
test "emit_stmt: block" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  emit_stmt(
    @ast.Block(
      [
        @ast.VarDecl("int", "x", Some(@ast.IntLiteral(10))),
        @ast.VarDecl("int", "y", Some(@ast.IntLiteral(20))),
        @ast.Return(
          Some(@ast.BinaryOp(Add, @ast.Ident("x"), @ast.Ident("y"))),
        ),
      ],
    ),
    code,
    ctx,
  )
  // i32.const 10; local.set 0; i32.const 20; local.set 1; local.get 0; local.get 1; i32.add; return
  inspect(
    bytes_to_hex(code),
    content="41 0A 21 00 41 14 21 01 20 00 20 01 6A 0F",
  )
}

/// 統合: int x = 10; int y = 20; return x + y;
test "emit_stmt: var decl and return" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  emit_stmt(@ast.VarDecl("int", "x", Some(@ast.IntLiteral(10))), code, ctx)
  emit_stmt(@ast.VarDecl("int", "y", Some(@ast.IntLiteral(20))), code, ctx)
  emit_stmt(
    @ast.Return(Some(@ast.BinaryOp(Add, @ast.Ident("x"), @ast.Ident("y")))),
    code,
    ctx,
  )
  // i32.const 10; local.set 0; i32.const 20; local.set 1; local.get 0; local.get 1; i32.add; return
  inspect(
    bytes_to_hex(code),
    content="41 0A 21 00 41 14 21 01 20 00 20 01 6A 0F",
  )
}

// === compile_program テスト ===

/// 単一関数: int main() { return 42; }
test "compile_program: single function return 42" {
  let program : @ast.Program = {
    top_levels: [
      @ast.FuncDef(
        "int",
        "main",
        [],
        @ast.Block([@ast.Return(Some(@ast.IntLiteral(42)))]),
      ),
    ],
  }
  let wasm = compile_program(program)
  // Wasm バイナリが生成されていることを確認（先頭8バイトがヘッダ）
  inspect(bytes_to_hex(Array::from_iter(wasm[0:8].iter())), content="00 61 73 6D 01 00 00 00")
  // バイナリサイズが妥当であることを確認（ヘッダ + セクション群）
  inspect(wasm.length() > 8, content="true")
}

/// 複数関数: add(a, b) + main() → function index が正しく管理される
test "compile_program: multiple functions" {
  let program : @ast.Program = {
    top_levels: [
      @ast.FuncDef(
        "int",
        "add",
        [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
        @ast.Block(
          [
            @ast.Return(
              Some(@ast.BinaryOp(Add, @ast.Ident("a"), @ast.Ident("b"))),
            ),
          ],
        ),
      ),
      @ast.FuncDef(
        "int",
        "main",
        [],
        @ast.Block(
          [
            @ast.Return(
              Some(
                @ast.Call("add", [@ast.IntLiteral(3), @ast.IntLiteral(4)]),
              ),
            ),
          ],
        ),
      ),
    ],
  }
  let wasm = compile_program(program)
  // ヘッダが正しい
  inspect(bytes_to_hex(Array::from_iter(wasm[0:8].iter())), content="00 61 73 6D 01 00 00 00")
  // 生成されたバイナリが妥当なサイズ
  inspect(wasm.length() > 20, content="true")
}

/// void 関数の戻り値型
test "compile_program: void function" {
  let program : @ast.Program = {
    top_levels: [
      @ast.FuncDef(
        "void",
        "noop",
        [],
        @ast.Block([@ast.Return(None)]),
      ),
      @ast.FuncDef(
        "int",
        "main",
        [],
        @ast.Block([@ast.Return(Some(@ast.IntLiteral(0)))]),
      ),
    ],
  }
  let wasm = compile_program(program)
  inspect(bytes_to_hex(Array::from_iter(wasm[0:8].iter())), content="00 61 73 6D 01 00 00 00")
}

/// 関数が0個の場合はエラー
test "compile_program: no functions error" {
  let program : @ast.Program = { top_levels: [] }
  let result : Result[Array[Byte], Error] = try {
    Ok(compile_program(program))
  } catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// === if/else 文テスト ===

/// if (x < 0) return -x; → 条件 + if void + then + end
test "emit_stmt: if without else" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "x" }],
  )
  let code : Array[Byte] = []
  emit_stmt(
    @ast.If(
      @ast.BinaryOp(Lt, @ast.Ident("x"), @ast.IntLiteral(0)),
      @ast.Return(Some(@ast.UnaryOp(Neg, @ast.Ident("x")))),
      None,
    ),
    code,
    ctx,
  )
  // local.get 0; i32.const 0; i32.lt_s; if void; i32.const 0; local.get 0; i32.sub; return; end
  inspect(
    bytes_to_hex(code),
    content="20 00 41 00 48 04 40 41 00 20 00 6B 0F 0B",
  )
}

/// if (x) return 1; else return 0; → 条件 + if void + then + else + end
test "emit_stmt: if with else" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "x" }],
  )
  let code : Array[Byte] = []
  emit_stmt(
    @ast.If(
      @ast.Ident("x"),
      @ast.Return(Some(@ast.IntLiteral(1))),
      Some(@ast.Return(Some(@ast.IntLiteral(0)))),
    ),
    code,
    ctx,
  )
  // local.get 0; if void; i32.const 1; return; else; i32.const 0; return; end
  inspect(
    bytes_to_hex(code),
    content="20 00 04 40 41 01 0F 05 41 00 0F 0B",
  )
}

/// if/else を含む関数の compile_program テスト
test "compile_program: function with if/else" {
  let program : @ast.Program = {
    top_levels: [
      @ast.FuncDef(
        "int",
        "abs_val",
        [{ type_name: "int", name: "x" }],
        @ast.Block(
          [
            @ast.If(
              @ast.BinaryOp(Lt, @ast.Ident("x"), @ast.IntLiteral(0)),
              @ast.Return(Some(@ast.UnaryOp(Neg, @ast.Ident("x")))),
              Some(@ast.Return(Some(@ast.Ident("x")))),
            ),
          ],
        ),
      ),
      @ast.FuncDef(
        "int",
        "main",
        [],
        @ast.Block(
          [
            @ast.Return(
              Some(@ast.Call("abs_val", [@ast.IntLiteral(-5)])),
            ),
          ],
        ),
      ),
    ],
  }
  let wasm = compile_program(program)
  inspect(bytes_to_hex(Array::from_iter(wasm[0:8].iter())), content="00 61 73 6D 01 00 00 00")
  inspect(wasm.length() > 20, content="true")
}

// === while 文テスト ===

/// while (x > 0) { x = x - 1; } → block + loop + cond + br_if + body + br + end + end
test "emit_stmt: while loop" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "x" }],
  )
  let code : Array[Byte] = []
  emit_stmt(
    @ast.While(
      @ast.BinaryOp(Gt, @ast.Ident("x"), @ast.IntLiteral(0)),
      @ast.Block(
        [
          @ast.ExprStmt(
            @ast.Assign(@ast.Ident("x"), @ast.BinaryOp(Sub, @ast.Ident("x"), @ast.IntLiteral(1))),
          ),
        ],
      ),
    ),
    code,
    ctx,
  )
  // block void; loop void; local.get 0; i32.const 0; i32.gt_s; i32.eqz; br_if 1;
  // local.get 0; i32.const 1; i32.sub; local.set 0; br 0; end; end
  inspect(
    bytes_to_hex(code),
    content="02 40 03 40 20 00 41 00 4A 45 0D 01 20 00 41 01 6B 22 00 1A 0C 00 0B 0B",
  )
}

/// 階乗計算: while ループを含む関数の compile_program テスト
test "compile_program: function with while loop (factorial)" {
  let program : @ast.Program = {
    top_levels: [
      @ast.FuncDef(
        "int",
        "fact",
        [{ type_name: "int", name: "n" }],
        @ast.Block(
          [
            @ast.VarDecl("int", "result", Some(@ast.IntLiteral(1))),
            @ast.While(
              @ast.BinaryOp(Gt, @ast.Ident("n"), @ast.IntLiteral(0)),
              @ast.Block(
                [
                  @ast.ExprStmt(
                    @ast.Assign(
                      @ast.Ident("result"),
                      @ast.BinaryOp(Mul, @ast.Ident("result"), @ast.Ident("n")),
                    ),
                  ),
                  @ast.ExprStmt(
                    @ast.Assign(
                      @ast.Ident("n"),
                      @ast.BinaryOp(Sub, @ast.Ident("n"), @ast.IntLiteral(1)),
                    ),
                  ),
                ],
              ),
            ),
            @ast.Return(Some(@ast.Ident("result"))),
          ],
        ),
      ),
      @ast.FuncDef(
        "int",
        "main",
        [],
        @ast.Block(
          [
            @ast.Return(
              Some(@ast.Call("fact", [@ast.IntLiteral(5)])),
            ),
          ],
        ),
      ),
    ],
  }
  let wasm = compile_program(program)
  inspect(bytes_to_hex(Array::from_iter(wasm[0:8].iter())), content="00 61 73 6D 01 00 00 00")
  inspect(wasm.length() > 20, content="true")
}

// === 短絡評価テスト ===

/// && 短絡評価: 1 && 2 → if(1, 2, 0)
/// i32.const 1; if i32; i32.const 2; else; i32.const 0; end
test "emit_expr: logical and short-circuit" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(LogAnd, @ast.IntLiteral(1), @ast.IntLiteral(2)),
    code,
    empty_ctx(),
  )
  // i32.const 1 (41 01); if i32 (04 7F); i32.const 2 (41 02); else (05); i32.const 0 (41 00); end (0B)
  inspect(bytes_to_hex(code), content="41 01 04 7F 41 02 05 41 00 0B")
}

/// || 短絡評価: 0 || 3 → if(0, 1, 3)
/// i32.const 0; if i32; i32.const 1; else; i32.const 3; end
test "emit_expr: logical or short-circuit" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(LogOr, @ast.IntLiteral(0), @ast.IntLiteral(3)),
    code,
    empty_ctx(),
  )
  // i32.const 0 (41 00); if i32 (04 7F); i32.const 1 (41 01); else (05); i32.const 3 (41 03); end (0B)
  inspect(bytes_to_hex(code), content="41 00 04 7F 41 01 05 41 03 0B")
}

/// && 短絡評価（変数参照付き）: a && b
test "emit_expr: logical and with idents" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
  )
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(LogAnd, @ast.Ident("a"), @ast.Ident("b")),
    code,
    ctx,
  )
  // local.get 0 (20 00); if i32 (04 7F); local.get 1 (20 01); else (05); i32.const 0 (41 00); end (0B)
  inspect(bytes_to_hex(code), content="20 00 04 7F 20 01 05 41 00 0B")
}

/// || 短絡評価（変数参照付き）: a || b
test "emit_expr: logical or with idents" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
  )
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(LogOr, @ast.Ident("a"), @ast.Ident("b")),
    code,
    ctx,
  )
  // local.get 0 (20 00); if i32 (04 7F); i32.const 1 (41 01); else (05); local.get 1 (20 01); end (0B)
  inspect(bytes_to_hex(code), content="20 00 04 7F 41 01 05 20 01 0B")
}

/// ネストした短絡評価: (a && b) || c
test "emit_expr: nested logical and-or" {
  let ctx = CodegenContext::from_params(
    [
      { type_name: "int", name: "a" },
      { type_name: "int", name: "b" },
      { type_name: "int", name: "c" },
    ],
  )
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(
      LogOr,
      @ast.BinaryOp(LogAnd, @ast.Ident("a"), @ast.Ident("b")),
      @ast.Ident("c"),
    ),
    code,
    ctx,
  )
  // (a && b): local.get 0; if i32; local.get 1; else; i32.const 0; end
  // || c: if i32; i32.const 1; else; local.get 2; end
  inspect(
    bytes_to_hex(code),
    content="20 00 04 7F 20 01 05 41 00 0B 04 7F 41 01 05 20 02 0B",
  )
}

/// ローカル変数を持つ関数のコンパイル
test "compile_program: function with locals" {
  let program : @ast.Program = {
    top_levels: [
      @ast.FuncDef(
        "int",
        "main",
        [],
        @ast.Block(
          [
            @ast.VarDecl("int", "x", Some(@ast.IntLiteral(10))),
            @ast.VarDecl("int", "y", Some(@ast.IntLiteral(20))),
            @ast.Return(
              Some(@ast.BinaryOp(Add, @ast.Ident("x"), @ast.Ident("y"))),
            ),
          ],
        ),
      ),
    ],
  }
  let wasm = compile_program(program)
  inspect(bytes_to_hex(Array::from_iter(wasm[0:8].iter())), content="00 61 73 6D 01 00 00 00")
  inspect(wasm.length() > 20, content="true")
}
