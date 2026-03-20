test "encode_global_section: mutable i32 (stack pointer)" {
  // スタックポインタ: mutable i32, 初期値 65536 (1ページのトップ)
  let init_expr = make_i32_const_expr(65536)
  let globals : Array[GlobalEntry] = [
    {
      global_type: { valtype: I32, mutability: Mutable },
      init_expr,
    },
  ]
  let section = encode_global_section(globals)
  // Section id: 0x06 (Global)
  inspect!(section[0], content="b'\\x06'")
  // Payload size: 8 bytes
  // count(1) + valtype(1) + mut(1) + i32.const(1) + value(3 bytes LEB128 for 65536) + end(1)
  inspect!(section[1], content="b'\\x08'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // ValType: i32 (0x7F)
  inspect!(section[3], content="b'\\x7F'")
  // Mutability: mutable (0x01)
  inspect!(section[4], content="b'\\x01'")
  // i32.const opcode (0x41)
  inspect!(section[5], content="b'\\x41'")
  // 65536 in signed LEB128: 0x80 0x80 0x04
  inspect!(section[6], content="b'\\x80'")
  inspect!(section[7], content="b'\\x80'")
  inspect!(section[8], content="b'\\x04'")
  // end (0x0B)
  inspect!(section[9], content="b'\\x0B'")
  inspect!(section.length(), content="10")
}

test "encode_global_section: immutable i32 constant" {
  let init_expr = make_i32_const_expr(42)
  let globals : Array[GlobalEntry] = [
    {
      global_type: { valtype: I32, mutability: Immutable },
      init_expr,
    },
  ]
  let section = encode_global_section(globals)
  // Section id: 0x06
  inspect!(section[0], content="b'\\x06'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // ValType: i32 (0x7F)
  inspect!(section[3], content="b'\\x7F'")
  // Mutability: immutable (0x00)
  inspect!(section[4], content="b'\\x00'")
  // i32.const 42: 0x41 0x2A
  inspect!(section[5], content="b'\\x41'")
  inspect!(section[6], content="b'\\x2A'")
  // end (0x0B)
  inspect!(section[7], content="b'\\x0B'")
}

test "encode_global_section: empty" {
  let section = encode_global_section([])
  // Section id: 0x06 + size: 0x01 + count: 0x00
  inspect!(section, content="[b'\\x06', b'\\x01', b'\\x00']")
}

test "make_i32_const_expr: zero" {
  let expr = make_i32_const_expr(0)
  // i32.const 0 + end
  inspect!(expr, content="[b'\\x41', b'\\x00', b'\\x0B']")
}

test "make_i32_const_expr: negative" {
  let expr = make_i32_const_expr(-1)
  // i32.const -1 (sleb128: 0x7F) + end
  inspect!(expr, content="[b'\\x41', b'\\x7F', b'\\x0B']")
}

test "encode_global_type: mutable i32" {
  let gt = encode_global_type({ valtype: I32, mutability: Mutable })
  inspect!(gt, content="[b'\\x7F', b'\\x01']")
}

test "encode_global_type: immutable i32" {
  let gt = encode_global_type({ valtype: I32, mutability: Immutable })
  inspect!(gt, content="[b'\\x7F', b'\\x00']")
}

test "encode_global_section: multiple globals" {
  // 2つのグローバル変数: SP (mutable) + 定数 (immutable)
  let globals : Array[GlobalEntry] = [
    {
      global_type: { valtype: I32, mutability: Mutable },
      init_expr: make_i32_const_expr(65536),
    },
    {
      global_type: { valtype: I32, mutability: Immutable },
      init_expr: make_i32_const_expr(0),
    },
  ]
  let section = encode_global_section(globals)
  // Section id: 0x06
  inspect!(section[0], content="b'\\x06'")
  // Count: 2
  inspect!(section[2], content="b'\\x02'")
}
