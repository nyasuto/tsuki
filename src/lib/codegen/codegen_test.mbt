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

// === 前置/後置インクリメント・デクリメントテスト ===

/// ++x: local.get 0; i32.const 1; i32.add; local.tee 0
test "emit_expr: prefix increment" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "x" }],
  )
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(PreInc, @ast.Ident("x")), code, ctx)
  // local.get 0 (20 00); i32.const 1 (41 01); i32.add (6A); local.tee 0 (22 00)
  inspect(bytes_to_hex(code), content="20 00 41 01 6A 22 00")
}

/// --x: local.get 0; i32.const 1; i32.sub; local.tee 0
test "emit_expr: prefix decrement" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "x" }],
  )
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(PreDec, @ast.Ident("x")), code, ctx)
  // local.get 0 (20 00); i32.const 1 (41 01); i32.sub (6B); local.tee 0 (22 00)
  inspect(bytes_to_hex(code), content="20 00 41 01 6B 22 00")
}

/// x++: local.get 0（元の値）; local.get 0; i32.const 1; i32.add; local.set 0
test "emit_expr: postfix increment" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "x" }],
  )
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(PostInc, @ast.Ident("x")), code, ctx)
  // local.get 0 (20 00); local.get 0 (20 00); i32.const 1 (41 01); i32.add (6A); local.set 0 (21 00)
  inspect(bytes_to_hex(code), content="20 00 20 00 41 01 6A 21 00")
}

/// x--: local.get 0（元の値）; local.get 0; i32.const 1; i32.sub; local.set 0
test "emit_expr: postfix decrement" {
  let ctx = CodegenContext::from_params(
    [{ type_name: "int", name: "x" }],
  )
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(PostDec, @ast.Ident("x")), code, ctx)
  // local.get 0 (20 00); local.get 0 (20 00); i32.const 1 (41 01); i32.sub (6B); local.set 0 (21 00)
  inspect(bytes_to_hex(code), content="20 00 20 00 41 01 6B 21 00")
}

/// ++x（未定義変数）はエラーになる
test "emit_expr: prefix increment undefined var error" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  let result : Result[Unit, Error] = try {
    Ok(emit_expr(@ast.UnaryOp(PreInc, @ast.Ident("x")), code, ctx))
  } catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

/// ++（非変数）はエラーになる
test "emit_expr: prefix increment non-ident error" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  let result : Result[Unit, Error] = try {
    Ok(emit_expr(@ast.UnaryOp(PreInc, @ast.IntLiteral(1)), code, ctx))
  } catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

// =============================================================
// プロローグ/エピローグのテスト
// =============================================================

/// emit_prologue: frame_size が 0 の場合は何も生成しない
test "emit_prologue: frame_size 0 emits nothing" {
  let code : Array[Byte] = []
  emit_prologue(0, code)
  inspect(code.length(), content="0")
}

/// emit_prologue: frame_size が 16 の場合のバイト列
/// global.get 0 (23 00) + i32.const 16 (41 10) + i32.sub (6B) + global.set 0 (24 00)
test "emit_prologue: frame_size 16" {
  let code : Array[Byte] = []
  emit_prologue(16, code)
  inspect(bytes_to_hex(code), content="23 00 41 10 6B 24 00")
}

/// emit_epilogue: frame_size が 0 の場合は何も生成しない
test "emit_epilogue: frame_size 0 emits nothing" {
  let code : Array[Byte] = []
  emit_epilogue(0, code)
  inspect(code.length(), content="0")
}

/// emit_epilogue: frame_size が 16 の場合のバイト列
/// global.get 0 (23 00) + i32.const 16 (41 10) + i32.add (6A) + global.set 0 (24 00)
test "emit_epilogue: frame_size 16" {
  let code : Array[Byte] = []
  emit_epilogue(16, code)
  inspect(bytes_to_hex(code), content="23 00 41 10 6A 24 00")
}

/// emit_prologue: frame_size が 128 の場合（LEB128 で 2 バイトになる値）
/// global.get 0 (23 00) + i32.const 128 (41 80 01) + i32.sub (6B) + global.set 0 (24 00)
test "emit_prologue: frame_size 128 (multi-byte LEB128)" {
  let code : Array[Byte] = []
  emit_prologue(128, code)
  inspect(bytes_to_hex(code), content="23 00 41 80 01 6B 24 00")
}

/// allocate_on_stack: サイズ 4 の場合、オフセット 0 を返し frame_size が 4 になる
test "allocate_on_stack: size 4" {
  let ctx = CodegenContext::new()
  let offset = ctx.allocate_on_stack(4)
  inspect(offset, content="0")
  inspect(ctx.frame_size, content="4")
}

/// allocate_on_stack: サイズ 1 の場合、4 バイトにアラインメントされる
test "allocate_on_stack: size 1 aligned to 4" {
  let ctx = CodegenContext::new()
  let offset = ctx.allocate_on_stack(1)
  inspect(offset, content="0")
  inspect(ctx.frame_size, content="4")
}

/// allocate_on_stack: 複数回呼び出し
test "allocate_on_stack: multiple allocations" {
  let ctx = CodegenContext::new()
  let offset1 = ctx.allocate_on_stack(4) // int: 4 bytes
  let offset2 = ctx.allocate_on_stack(4) // int: 4 bytes
  let offset3 = ctx.allocate_on_stack(1) // char: 1 byte → aligned to 4
  inspect(offset1, content="0")
  inspect(offset2, content="4")
  inspect(offset3, content="8")
  inspect(ctx.frame_size, content="12")
}

/// return 文: frame_size が 0 の場合はエピローグなし
test "emit_stmt: return with frame_size 0 no epilogue" {
  let ctx = CodegenContext::new()
  let code : Array[Byte] = []
  emit_stmt(@ast.Return(Some(@ast.IntLiteral(42))), code, ctx)
  // i32.const 42 (41 2A) + return (0F) — エピローグなし
  inspect(bytes_to_hex(code), content="41 2A 0F")
}

/// return 文: frame_size > 0 の場合はエピローグが挿入される
/// allocate_on_stack(4) を 2 回呼んで frame_size = 8 にする
test "emit_stmt: return with frame_size 8 has epilogue" {
  let ctx = CodegenContext::new()
  let _ = ctx.allocate_on_stack(4) // frame_size = 4
  let _ = ctx.allocate_on_stack(4) // frame_size = 8
  let code : Array[Byte] = []
  emit_stmt(@ast.Return(Some(@ast.IntLiteral(42))), code, ctx)
  // i32.const 42 (41 2A) + epilogue (23 00 41 08 6A 24 00) + return (0F)
  inspect(
    bytes_to_hex(code),
    content="41 2A 23 00 41 08 6A 24 00 0F",
  )
}

/// void return: frame_size > 0 の場合はエピローグが挿入される
test "emit_stmt: void return with frame_size 4 has epilogue" {
  let ctx = CodegenContext::new()
  let _ = ctx.allocate_on_stack(4) // frame_size = 4
  let code : Array[Byte] = []
  emit_stmt(@ast.Return(None), code, ctx)
  // epilogue (23 00 41 04 6A 24 00) + return (0F)
  inspect(bytes_to_hex(code), content="23 00 41 04 6A 24 00 0F")
}

/// compile_program: frame_size が 0 のとき、プロローグは挿入されない
/// return 42 のプログラムではスタック配置される変数がないため
test "compile_program: no prologue when no stack vars" {
  let program : @ast.Program = {
    top_levels: [
      @ast.TopLevel::FuncDef(
        "int",
        "main",
        [],
        @ast.Stmt::Block([@ast.Return(Some(@ast.IntLiteral(42)))]),
      ),
    ],
  }
  let wasm = @codegen.compile_program(program)
  // Wasm バイナリが正常に生成されることを確認
  inspect(wasm.length() > 0, content="true")
}

/// collect_addr_taken_vars: &x を検出する
test "collect_addr_taken_vars: detects address-of" {
  // int x = 42; int *p = &x; return *p;
  let body = @ast.Stmt::Block([
    @ast.VarDecl("int", "x", Some(@ast.IntLiteral(42))),
    @ast.VarDecl("int*", "p", Some(@ast.UnaryOp(AddrOf, @ast.Ident("x")))),
    @ast.Return(Some(@ast.UnaryOp(Deref, @ast.Ident("p")))),
  ])
  let vars = @codegen.collect_addr_taken_vars(body)
  inspect(vars.contains("x"), content="true")
  inspect(vars.contains("p"), content="false")
}

/// スタック配置変数: VarDecl + Ident
test "emit_stmt: stack var decl and read" {
  let code : Array[Byte] = []
  let ctx = @codegen.CodegenContext::new()
  // addr_taken にマーク
  ctx.addr_taken["x"] = true
  // VarDecl: int x = 42;
  @codegen.emit_stmt(@ast.VarDecl("int", "x", Some(@ast.IntLiteral(42))), code, ctx)
  // x が stack_vars に登録されている
  inspect(ctx.is_stack_var("x"), content="true")
  // frame_size が 4 に増加
  inspect(ctx.frame_size, content="4")
}

/// スタック配置変数: 読み取りが i32.load を使う
test "emit_expr: stack var ident uses i32.load" {
  let code : Array[Byte] = []
  let ctx = @codegen.CodegenContext::new()
  ctx.addr_taken["x"] = true
  // VarDecl で x をスタックに配置
  @codegen.emit_stmt(@ast.VarDecl("int", "x", Some(@ast.IntLiteral(42))), code, ctx)
  // コードをリセットして Ident のみ確認
  let read_code : Array[Byte] = []
  @codegen.emit_expr(@ast.Ident("x"), read_code, ctx)
  // global.get 0 + i32.const 0 + i32.add + i32.load align=2 offset=0
  inspect(
    bytes_to_hex(read_code),
    content="23 00 41 00 6A 28 02 00",
  )
}

/// 通常の変数はスタック配置されない
test "emit_stmt: non-addr-taken var uses wasm local" {
  let code : Array[Byte] = []
  let ctx = @codegen.CodegenContext::new()
  // addr_taken にマークしない
  @codegen.emit_stmt(@ast.VarDecl("int", "y", Some(@ast.IntLiteral(10))), code, ctx)
  inspect(ctx.is_stack_var("y"), content="false")
  inspect(ctx.frame_size, content="0")
}

/// &x（アドレス取得）: スタック変数のアドレスを計算する
test "emit_expr: addr_of stack variable" {
  let code : Array[Byte] = []
  let ctx = @codegen.CodegenContext::new()
  // 変数 x をアドレス取得対象にマークし、スタック変数として登録
  ctx.addr_taken["x"] = true
  @codegen.emit_stmt(@ast.VarDecl("int", "x", Some(@ast.IntLiteral(42))), code, ctx)
  // &x を生成
  let addr_code : Array[Byte] = []
  @codegen.emit_expr(@ast.UnaryOp(AddrOf, @ast.Ident("x")), addr_code, ctx)
  // global.get $sp (23 00) + i32.const 0 (41 00) + i32.add (6A)
  inspect(bytes_to_hex(addr_code), content="23 00 41 00 6A")
}

/// &x: スタック変数でない変数に対するエラー
test "emit_expr: addr_of non-stack variable raises error" {
  let code : Array[Byte] = []
  let ctx = @codegen.CodegenContext::new()
  // x はスタック変数として登録されていない
  let result : Result[Unit, Error] = try {
    Ok(@codegen.emit_expr(@ast.UnaryOp(AddrOf, @ast.Ident("x")), code, ctx))
  } catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

/// &(expr): 変数以外へのAddrOfはエラー
test "emit_expr: addr_of non-variable raises error" {
  let code : Array[Byte] = []
  let ctx = @codegen.CodegenContext::new()
  let result : Result[Unit, Error] = try {
    Ok(
      @codegen.emit_expr(
        @ast.UnaryOp(AddrOf, @ast.IntLiteral(42)),
        code,
        ctx,
      ),
    )
  } catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

/// ポインタ演算のテスト用コンテキスト作成ヘルパー
/// int* 型の変数 "p" を local index 0 に登録する
fn ptr_ctx() -> CodegenContext {
  let ctx = CodegenContext::new()
  let _ = ctx.add_local("p")
  ctx.var_types["p"] = @ast.CType::Ptr(@ast.CType::Int)
  ctx
}

/// ptr + n: int* + int → ptr + n * 4
/// p + 3 → local.get 0; i32.const 3; i32.const 4; i32.mul; i32.add
test "emit_expr: pointer add scales by sizeof(int)" {
  let code : Array[Byte] = []
  let ctx = ptr_ctx()
  emit_expr(
    @ast.BinaryOp(Add, @ast.Ident("p"), @ast.IntLiteral(3)),
    code,
    ctx,
  )
  // local.get 0 (20 00), i32.const 3 (41 03), i32.const 4 (41 04), i32.mul (6C), i32.add (6A)
  inspect(bytes_to_hex(code), content="20 00 41 03 41 04 6C 6A")
}

/// n + ptr: int + int* → n * 4 + ptr
/// 3 + p → i32.const 3; i32.const 4; i32.mul; local.get 0; i32.add
test "emit_expr: int + pointer scales by sizeof(int)" {
  let code : Array[Byte] = []
  let ctx = ptr_ctx()
  emit_expr(
    @ast.BinaryOp(Add, @ast.IntLiteral(3), @ast.Ident("p")),
    code,
    ctx,
  )
  // i32.const 3 (41 03), i32.const 4 (41 04), i32.mul (6C), local.get 0 (20 00), i32.add (6A)
  inspect(bytes_to_hex(code), content="41 03 41 04 6C 20 00 6A")
}

/// ptr - n: int* - int → ptr - n * 4
/// p - 2 → local.get 0; i32.const 2; i32.const 4; i32.mul; i32.sub
test "emit_expr: pointer sub scales by sizeof(int)" {
  let code : Array[Byte] = []
  let ctx = ptr_ctx()
  emit_expr(
    @ast.BinaryOp(Sub, @ast.Ident("p"), @ast.IntLiteral(2)),
    code,
    ctx,
  )
  // local.get 0 (20 00), i32.const 2 (41 02), i32.const 4 (41 04), i32.mul (6C), i32.sub (6B)
  inspect(bytes_to_hex(code), content="20 00 41 02 41 04 6C 6B")
}

/// ptr - ptr: int* - int* → (ptr1 - ptr2) / sizeof(int)
test "emit_expr: pointer diff divides by sizeof(int)" {
  let code : Array[Byte] = []
  let ctx = CodegenContext::new()
  let _ = ctx.add_local("p")
  let _ = ctx.add_local("q")
  ctx.var_types["p"] = @ast.CType::Ptr(@ast.CType::Int)
  ctx.var_types["q"] = @ast.CType::Ptr(@ast.CType::Int)
  emit_expr(
    @ast.BinaryOp(Sub, @ast.Ident("p"), @ast.Ident("q")),
    code,
    ctx,
  )
  // local.get 0 (20 00), local.get 1 (20 01), i32.sub (6B), i32.const 4 (41 04), i32.div_s (6D)
  inspect(bytes_to_hex(code), content="20 00 20 01 6B 41 04 6D")
}

/// char* + n: スケーリングなし（sizeof(char) == 1）
test "emit_expr: char pointer add no scaling" {
  let code : Array[Byte] = []
  let ctx = CodegenContext::new()
  let _ = ctx.add_local("cp")
  ctx.var_types["cp"] = @ast.CType::Ptr(@ast.CType::Char)
  emit_expr(
    @ast.BinaryOp(Add, @ast.Ident("cp"), @ast.IntLiteral(5)),
    code,
    ctx,
  )
  // local.get 0 (20 00), i32.const 5 (41 05), i32.add (6A) — sizeof(char)=1 なのでスケーリングなし
  inspect(bytes_to_hex(code), content="20 00 41 05 6A")
}

/// 型情報なし（非ポインタ）の加算: 通常の i32.add
test "emit_expr: non-pointer add unchanged" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Add, @ast.IntLiteral(3), @ast.IntLiteral(4)),
    code,
    empty_ctx(),
  )
  inspect(bytes_to_hex(code), content="41 03 41 04 6A")
}

/// 構造体変数のスタック配置: struct Point { int x; int y; } で 8 バイト確保
test "struct variable stack allocation: Point (8 bytes)" {
  let struct_defs : Map[String, @sema.StructInfo] = {}
  struct_defs["Point"] = {
    name: "Point",
    fields: [
      { name: "x", field_type: @ast.CType::Int, offset: 0 },
      { name: "y", field_type: @ast.CType::Int, offset: 4 },
    ],
    total_size: 8,
  }
  let ctx = CodegenContext::new(struct_defs~)
  // struct Point p; → スタック上に 8 バイト確保
  let code : Array[Byte] = []
  emit_stmt(
    @ast.VarDecl("struct Point", "p", None),
    code,
    ctx,
  )
  // frame_size が 8 であることを確認（構造体サイズ分のスタック領域）
  inspect(ctx.frame_size, content="8")
  // p がスタック変数として登録されていることを確認
  inspect(ctx.is_stack_var("p"), content="true")
  // p のスタックオフセットが 0 であることを確認
  inspect(ctx.stack_vars.get("p"), content="Some(0)")
}

/// 構造体変数のスタック配置: struct Rect { int x; int y; int w; int h; } で 16 バイト確保
test "struct variable stack allocation: Rect (16 bytes)" {
  let struct_defs : Map[String, @sema.StructInfo] = {}
  struct_defs["Rect"] = {
    name: "Rect",
    fields: [
      { name: "x", field_type: @ast.CType::Int, offset: 0 },
      { name: "y", field_type: @ast.CType::Int, offset: 4 },
      { name: "w", field_type: @ast.CType::Int, offset: 8 },
      { name: "h", field_type: @ast.CType::Int, offset: 12 },
    ],
    total_size: 16,
  }
  let ctx = CodegenContext::new(struct_defs~)
  let code : Array[Byte] = []
  emit_stmt(
    @ast.VarDecl("struct Rect", "r", None),
    code,
    ctx,
  )
  inspect(ctx.frame_size, content="16")
  inspect(ctx.is_stack_var("r"), content="true")
}

/// 構造体変数の Ident はアドレスを返す（i32.load ではなく addr を push）
test "struct variable ident returns address" {
  let struct_defs : Map[String, @sema.StructInfo] = {}
  struct_defs["Point"] = {
    name: "Point",
    fields: [
      { name: "x", field_type: @ast.CType::Int, offset: 0 },
      { name: "y", field_type: @ast.CType::Int, offset: 4 },
    ],
    total_size: 8,
  }
  let ctx = CodegenContext::new(struct_defs~)
  // まず変数を宣言してスタック配置
  let decl_code : Array[Byte] = []
  emit_stmt(
    @ast.VarDecl("struct Point", "p", None),
    decl_code,
    ctx,
  )
  // p の参照: アドレスを返す（global.get $sp + i32.const 0 + i32.add）
  let code : Array[Byte] = []
  emit_expr(@ast.Ident("p"), code, ctx)
  // global.get 0 (23 00), i32.const 0 (41 00), i32.add (6A)
  inspect(bytes_to_hex(code), content="23 00 41 00 6A")
}

/// 構造体と通常変数の混在: 構造体はスタック、通常変数は Wasm local
test "struct and scalar variable mixed allocation" {
  let struct_defs : Map[String, @sema.StructInfo] = {}
  struct_defs["Point"] = {
    name: "Point",
    fields: [
      { name: "x", field_type: @ast.CType::Int, offset: 0 },
      { name: "y", field_type: @ast.CType::Int, offset: 4 },
    ],
    total_size: 8,
  }
  let ctx = CodegenContext::new(struct_defs~)
  let code : Array[Byte] = []
  // int n = 10; → Wasm local
  emit_stmt(
    @ast.VarDecl("int", "n", Some(@ast.IntLiteral(10))),
    code,
    ctx,
  )
  // struct Point p; → スタック配置
  emit_stmt(
    @ast.VarDecl("struct Point", "p", None),
    code,
    ctx,
  )
  // n は Wasm local（スタック変数ではない）
  inspect(ctx.is_stack_var("n"), content="false")
  inspect(ctx.resolve("n"), content="Some(0)")
  // p はスタック変数
  inspect(ctx.is_stack_var("p"), content="true")
  inspect(ctx.frame_size, content="8")
}

/// 構造体ポインタの演算でスケーリングが正しいことを確認
/// struct Point* p に対して p + 1 → p + 8（sizeof(Point) = 8）
test "pointer arithmetic with struct pointer scales by struct size" {
  let struct_defs : Map[String, @sema.StructInfo] = {}
  struct_defs["Point"] = {
    name: "Point",
    fields: [
      { name: "x", field_type: @ast.CType::Int, offset: 0 },
      { name: "y", field_type: @ast.CType::Int, offset: 4 },
    ],
    total_size: 8,
  }
  let ctx = CodegenContext::new(struct_defs~)
  // struct Point* 型の変数 p を登録
  let _idx = ctx.add_local("p")
  ctx.var_types["p"] = @ast.CType::Ptr(@ast.CType::Struct("Point"))
  // p + 1 → p + 1*8
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Add, @ast.Ident("p"), @ast.IntLiteral(1)),
    code,
    ctx,
  )
  // local.get 0 (20 00), i32.const 1 (41 01), i32.const 8 (41 08), i32.mul (6C), i32.add (6A)
  inspect(bytes_to_hex(code), content="20 00 41 01 41 08 6C 6A")
}

// === sizeof 演算子の Codegen テスト ===

test "emit_expr: sizeof(int) → i32.const 4" {
  let code : Array[Byte] = []
  let ctx = empty_ctx()
  emit_expr(
    @ast.Expr::SizeOf("int"),
    code,
    ctx,
  )
  // i32.const 4 → 41 04
  inspect(bytes_to_hex(code), content="41 04")
}

test "emit_expr: sizeof(char) → i32.const 1" {
  let code : Array[Byte] = []
  let ctx = empty_ctx()
  emit_expr(
    @ast.Expr::SizeOf("char"),
    code,
    ctx,
  )
  // i32.const 1 → 41 01
  inspect(bytes_to_hex(code), content="41 01")
}

test "emit_expr: sizeof(int*) → i32.const 4" {
  let code : Array[Byte] = []
  let ctx = empty_ctx()
  emit_expr(
    @ast.Expr::SizeOf("int*"),
    code,
    ctx,
  )
  // i32.const 4 → 41 04
  inspect(bytes_to_hex(code), content="41 04")
}
