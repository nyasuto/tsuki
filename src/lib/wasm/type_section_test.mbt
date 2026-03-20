test "ValType to_byte: I32" {
  inspect!(ValType::I32.to_byte(), content="b'\\x7F'")
}

test "ValType to_byte: I64" {
  inspect!(ValType::I64.to_byte(), content="b'\\x7E'")
}

test "encode_func_type: () -> ()" {
  // パラメータなし、戻り値なしの関数シグネチャ
  let ft : FuncType = { params: [], results: [] }
  let bytes = encode_func_type(ft)
  // 0x60 (functype marker) + 0x00 (0 params) + 0x00 (0 results)
  inspect!(bytes, content="[b'\\x60', b'\\x00', b'\\x00']")
}

test "encode_func_type: () -> i32" {
  // パラメータなし、戻り値 i32 の関数シグネチャ（main 関数に相当）
  let ft : FuncType = { params: [], results: [I32] }
  let bytes = encode_func_type(ft)
  // 0x60 + 0x00 (0 params) + 0x01 (1 result) + 0x7F (i32)
  inspect!(bytes, content="[b'\\x60', b'\\x00', b'\\x01', b'\\x7F']")
}

test "encode_func_type: (i32, i32) -> i32" {
  // 2つの i32 パラメータ、戻り値 i32（add 関数に相当）
  let ft : FuncType = { params: [I32, I32], results: [I32] }
  let bytes = encode_func_type(ft)
  // 0x60 + 0x02 (2 params) + 0x7F + 0x7F + 0x01 (1 result) + 0x7F
  inspect!(
    bytes,
    content="[b'\\x60', b'\\x02', b'\\x7F', b'\\x7F', b'\\x01', b'\\x7F']",
  )
}

test "encode_func_type: (i32) -> ()" {
  // 1つの i32 パラメータ、戻り値なし（void 関数に相当）
  let ft : FuncType = { params: [I32], results: [] }
  let bytes = encode_func_type(ft)
  // 0x60 + 0x01 (1 param) + 0x7F (i32) + 0x00 (0 results)
  inspect!(bytes, content="[b'\\x60', b'\\x01', b'\\x7F', b'\\x00']")
}

test "encode_type_section: single functype () -> i32" {
  let func_types : Array[FuncType] = [{ params: [], results: [I32] }]
  let section = encode_type_section(func_types)
  // Section id: 0x01 (Type)
  inspect!(section[0], content="b'\\x01'")
  // Payload size: 5 bytes (count(1) + functype(4) = 0x60 + 0x00 + 0x01 + 0x7F)
  inspect!(section[1], content="b'\\x05'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // functype: 0x60 0x00 0x01 0x7F
  inspect!(section[3], content="b'\\x60'")
  inspect!(section[4], content="b'\\x00'")
  inspect!(section[5], content="b'\\x01'")
  inspect!(section[6], content="b'\\x7F'")
  inspect!(section.length(), content="7")
}

test "encode_type_section: two functypes" {
  // () -> i32 と (i32, i32) -> i32 の2つのシグネチャ
  let func_types : Array[FuncType] = [
    { params: [], results: [I32] },
    { params: [I32, I32], results: [I32] },
  ]
  let section = encode_type_section(func_types)
  // Section id: 0x01
  inspect!(section[0], content="b'\\x01'")
  // Payload: count(1) + ft1(4) + ft2(6) = 11 bytes
  inspect!(section[1], content="b'\\x0B'")
  // Count: 2
  inspect!(section[2], content="b'\\x02'")
  // ft1: 0x60 0x00 0x01 0x7F
  inspect!(section[3], content="b'\\x60'")
  inspect!(section[4], content="b'\\x00'")
  inspect!(section[5], content="b'\\x01'")
  inspect!(section[6], content="b'\\x7F'")
  // ft2: 0x60 0x02 0x7F 0x7F 0x01 0x7F
  inspect!(section[7], content="b'\\x60'")
  inspect!(section[8], content="b'\\x02'")
  inspect!(section[9], content="b'\\x7F'")
  inspect!(section[10], content="b'\\x7F'")
  inspect!(section[11], content="b'\\x01'")
  inspect!(section[12], content="b'\\x7F'")
  inspect!(section.length(), content="13")
}

test "encode_type_section: empty" {
  let func_types : Array[FuncType] = []
  let section = encode_type_section(func_types)
  // Section id: 0x01 + size: 0x01 + count: 0x00
  inspect!(section, content="[b'\\x01', b'\\x01', b'\\x00']")
}
