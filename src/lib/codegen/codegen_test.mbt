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

/// IntLiteral(42) → i32.const 42
test "emit_expr: int literal 42" {
  let code : Array[Byte] = []
  emit_expr(@ast.IntLiteral(42), code)
  inspect(bytes_to_hex(code), content="41 2A")
}

/// IntLiteral(0) → i32.const 0
test "emit_expr: int literal 0" {
  let code : Array[Byte] = []
  emit_expr(@ast.IntLiteral(0), code)
  inspect(bytes_to_hex(code), content="41 00")
}

/// IntLiteral(-1) → i32.const -1 (sleb128: 0x7F)
test "emit_expr: int literal -1" {
  let code : Array[Byte] = []
  emit_expr(@ast.IntLiteral(-1), code)
  inspect(bytes_to_hex(code), content="41 7F")
}

/// IntLiteral(128) → i32.const 128 (sleb128: 0x80 0x01)
test "emit_expr: int literal 128" {
  let code : Array[Byte] = []
  emit_expr(@ast.IntLiteral(128), code)
  inspect(bytes_to_hex(code), content="41 80 01")
}

/// CharLiteral('A') → i32.const 65
test "emit_expr: char literal A" {
  let code : Array[Byte] = []
  emit_expr(@ast.CharLiteral('A'), code)
  inspect(bytes_to_hex(code), content="41 C1 00")
}

/// BinaryOp(Add, 3, 4) → i32.const 3; i32.const 4; i32.add
test "emit_expr: add 3 + 4" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Add, @ast.IntLiteral(3), @ast.IntLiteral(4)),
    code,
  )
  inspect(bytes_to_hex(code), content="41 03 41 04 6A")
}

/// BinaryOp(Sub, 10, 3) → i32.const 10; i32.const 3; i32.sub
test "emit_expr: sub 10 - 3" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Sub, @ast.IntLiteral(10), @ast.IntLiteral(3)),
    code,
  )
  inspect(bytes_to_hex(code), content="41 0A 41 03 6B")
}

/// BinaryOp(Mul, 6, 7) → i32.const 6; i32.const 7; i32.mul
test "emit_expr: mul 6 * 7" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Mul, @ast.IntLiteral(6), @ast.IntLiteral(7)),
    code,
  )
  inspect(bytes_to_hex(code), content="41 06 41 07 6C")
}

/// BinaryOp(Div, 20, 4) → i32.const 20; i32.const 4; i32.div_s
test "emit_expr: div 20 / 4" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Div, @ast.IntLiteral(20), @ast.IntLiteral(4)),
    code,
  )
  inspect(bytes_to_hex(code), content="41 14 41 04 6D")
}

/// BinaryOp(Mod, 17, 5) → i32.const 17; i32.const 5; i32.rem_s
test "emit_expr: mod 17 % 5" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Mod, @ast.IntLiteral(17), @ast.IntLiteral(5)),
    code,
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
  )
  inspect(bytes_to_hex(code), content="41 03 41 04 41 05 6C 6A")
}

/// 比較演算: 3 == 4 → i32.const 3; i32.const 4; i32.eq
test "emit_expr: eq 3 == 4" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Eq, @ast.IntLiteral(3), @ast.IntLiteral(4)),
    code,
  )
  inspect(bytes_to_hex(code), content="41 03 41 04 46")
}

/// 比較演算: 5 < 10 → i32.const 5; i32.const 10; i32.lt_s
test "emit_expr: lt 5 < 10" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(Lt, @ast.IntLiteral(5), @ast.IntLiteral(10)),
    code,
  )
  inspect(bytes_to_hex(code), content="41 05 41 0A 48")
}

/// ビット演算: 0xFF & 0x0F → i32.const 255; i32.const 15; i32.and
test "emit_expr: bitand" {
  let code : Array[Byte] = []
  emit_expr(
    @ast.BinaryOp(BitAnd, @ast.IntLiteral(255), @ast.IntLiteral(15)),
    code,
  )
  inspect(bytes_to_hex(code), content="41 FF 01 41 0F 71")
}

/// 単項演算: -42 → i32.const 0; i32.const 42; i32.sub
test "emit_expr: unary neg" {
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(Neg, @ast.IntLiteral(42)), code)
  inspect(bytes_to_hex(code), content="41 00 41 2A 6B")
}

/// 単項演算: !1 → i32.const 1; i32.eqz
test "emit_expr: unary lognot" {
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(LogNot, @ast.IntLiteral(1)), code)
  inspect(bytes_to_hex(code), content="41 01 45")
}

/// 単項演算: ~0 → i32.const 0; i32.const -1; i32.xor
test "emit_expr: unary bitnot" {
  let code : Array[Byte] = []
  emit_expr(@ast.UnaryOp(BitNot, @ast.IntLiteral(0)), code)
  inspect(bytes_to_hex(code), content="41 00 41 7F 73")
}
