test "encode_code_section: return 42 (simplest function)" {
  // int main() { return 42; }
  // 命令列: i32.const 42 (0x41 0x2A) + return は暗黙の end
  let section = encode_code_section(
    [{ locals: [], code: [b'\x41', b'\x2A'] }],
  )
  // Section id: 0x0A (Code)
  inspect!(section[0], content="b'\\x0A'")
  // Payload size: count(1) + body_size(1) + decl_count(1) + i32.const(1) + 42(1) + end(1) = 6
  inspect!(section[1], content="b'\\x06'")
  // Count: 1 function
  inspect!(section[2], content="b'\\x01'")
  // Body size: decl_count(1) + i32.const(1) + 42(1) + end(1) = 4
  inspect!(section[3], content="b'\\x04'")
  // Local decl count: 0
  inspect!(section[4], content="b'\\x00'")
  // i32.const
  inspect!(section[5], content="b'\\x41'")
  // 42
  inspect!(section[6], content="b'\\x2A'")
  // end
  inspect!(section[7], content="b'\\x0B'")
  inspect!(section.length(), content="8")
}

test "encode_code_section: function with locals" {
  // ローカル変数 2 つ（i32 が 2 つ）を持つ関数
  // int f() { int x = 10; int y = 20; return x + y; }
  // 命令列: i32.const 10 (0x41 0x0A), local.set 0 (0x21 0x00),
  //         i32.const 20 (0x41 0x14), local.set 1 (0x21 0x01),
  //         local.get 0 (0x20 0x00), local.get 1 (0x20 0x01), i32.add (0x6A)
  let code : Array[Byte] = [
    b'\x41', b'\x0A', // i32.const 10
    b'\x21', b'\x00', // local.set 0
    b'\x41', b'\x14', // i32.const 20
    b'\x21', b'\x01', // local.set 1
    b'\x20', b'\x00', // local.get 0
    b'\x20', b'\x01', // local.get 1
    b'\x6A', // i32.add
  ]
  let section = encode_code_section(
    [{ locals: [{ count: 2, valtype: I32 }], code }],
  )
  // Section id: 0x0A
  inspect!(section[0], content="b'\\x0A'")
  // Count: 1 function
  inspect!(section[2], content="b'\\x01'")
  // Body size: decl_count(1) + local_decl(2: count+valtype) + code(13) + end(1) = 17
  inspect!(section[3], content="b'\\x11'")
  // Local decl count: 1 (one group of 2 i32)
  inspect!(section[4], content="b'\\x01'")
  // Local group: count=2, type=i32(0x7F)
  inspect!(section[5], content="b'\\x02'")
  inspect!(section[6], content="b'\\x7F'")
  // First instruction: i32.const
  inspect!(section[7], content="b'\\x41'")
}

test "encode_code_section: multiple local groups" {
  // 異なる型のローカル変数: i32 x 3, i64 x 1
  let section = encode_code_section(
    [
      {
        locals: [{ count: 3, valtype: I32 }, { count: 1, valtype: I64 }],
        code: [b'\x41', b'\x00'], // i32.const 0
      },
    ],
  )
  // Section id: 0x0A
  inspect!(section[0], content="b'\\x0A'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // Body size: decl_count(1) + group1(2) + group2(2) + code(2) + end(1) = 8
  inspect!(section[3], content="b'\\x08'")
  // Local decl count: 2 groups
  inspect!(section[4], content="b'\\x02'")
  // Group 1: 3 x i32
  inspect!(section[5], content="b'\\x03'")
  inspect!(section[6], content="b'\\x7F'")
  // Group 2: 1 x i64
  inspect!(section[7], content="b'\\x01'")
  inspect!(section[8], content="b'\\x7E'")
}

test "encode_code_section: empty code section" {
  let section = encode_code_section([])
  // Section id(0x0A) + size(0x01) + count(0x00)
  inspect!(section, content="[b'\\x0A', b'\\x01', b'\\x00']")
}

test "encode_code_section: multiple functions" {
  // 2 つの関数本体
  let section = encode_code_section(
    [
      // 関数 0: return 1 (i32.const 1)
      { locals: [], code: [b'\x41', b'\x01'] },
      // 関数 1: return 2 (i32.const 2)
      { locals: [], code: [b'\x41', b'\x02'] },
    ],
  )
  // Section id: 0x0A
  inspect!(section[0], content="b'\\x0A'")
  // Count: 2
  inspect!(section[2], content="b'\\x02'")
  // Function 0: body_size=4 (decl_count(1) + code(2) + end(1))
  inspect!(section[3], content="b'\\x04'")
  inspect!(section[4], content="b'\\x00'") // 0 locals
  inspect!(section[5], content="b'\\x41'") // i32.const
  inspect!(section[6], content="b'\\x01'") // 1
  inspect!(section[7], content="b'\\x0B'") // end
  // Function 1: body_size=4
  inspect!(section[8], content="b'\\x04'")
  inspect!(section[9], content="b'\\x00'") // 0 locals
  inspect!(section[10], content="b'\\x41'") // i32.const
  inspect!(section[11], content="b'\\x02'") // 2
  inspect!(section[12], content="b'\\x0B'") // end
  inspect!(section.length(), content="13")
}

test "encode_code_section: function with no locals and nop" {
  // nop 命令のみの関数（void 関数相当）
  let section = encode_code_section(
    [{ locals: [], code: [b'\x01'] }],
  )
  // Section id: 0x0A
  inspect!(section[0], content="b'\\x0A'")
  // Body size: decl_count(1) + nop(1) + end(1) = 3
  inspect!(section[3], content="b'\\x03'")
  // Local decl count: 0
  inspect!(section[4], content="b'\\x00'")
  // nop
  inspect!(section[5], content="b'\\x01'")
  // end
  inspect!(section[6], content="b'\\x0B'")
}
