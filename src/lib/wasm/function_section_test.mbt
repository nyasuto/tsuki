test "encode_function_section: single function with type index 0" {
  // 1つの関数が type index 0 を参照
  let section = encode_function_section([0])
  // Section id: 0x03 (Function)
  inspect!(section[0], content="b'\\x03'")
  // Payload size: 2 bytes (count(1) + type_idx(1))
  inspect!(section[1], content="b'\\x02'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // Type index: 0
  inspect!(section[3], content="b'\\x00'")
  inspect!(section.length(), content="4")
}

test "encode_function_section: two functions with different type indices" {
  // 2つの関数: func0 → type 0, func1 → type 1
  let section = encode_function_section([0, 1])
  // Section id: 0x03
  inspect!(section[0], content="b'\\x03'")
  // Payload size: 3 bytes (count(1) + type_idx(1) + type_idx(1))
  inspect!(section[1], content="b'\\x03'")
  // Count: 2
  inspect!(section[2], content="b'\\x02'")
  // Type index 0
  inspect!(section[3], content="b'\\x00'")
  // Type index 1
  inspect!(section[4], content="b'\\x01'")
  inspect!(section.length(), content="5")
}

test "encode_function_section: multiple functions sharing same type" {
  // 3つの関数が全て同じ type index 0 を参照
  let section = encode_function_section([0, 0, 0])
  // Section id: 0x03
  inspect!(section[0], content="b'\\x03'")
  // Payload size: 4 bytes (count(1) + 3 * type_idx(1))
  inspect!(section[1], content="b'\\x04'")
  // Count: 3
  inspect!(section[2], content="b'\\x03'")
  // All type indices are 0
  inspect!(section[3], content="b'\\x00'")
  inspect!(section[4], content="b'\\x00'")
  inspect!(section[5], content="b'\\x00'")
  inspect!(section.length(), content="6")
}

test "encode_function_section: empty" {
  let section = encode_function_section([])
  // Section id: 0x03 + size: 0x01 + count: 0x00
  inspect!(section, content="[b'\\x03', b'\\x01', b'\\x00']")
}

test "encode_function_section: large type index (128+)" {
  // type index 128 は2バイトの ULEB128 エンコーディングが必要
  let section = encode_function_section([128])
  // Section id: 0x03
  inspect!(section[0], content="b'\\x03'")
  // Payload size: 3 bytes (count(1) + type_idx(2))
  inspect!(section[1], content="b'\\x03'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // Type index 128: ULEB128 = [0x80, 0x01]
  inspect!(section[3], content="b'\\x80'")
  inspect!(section[4], content="b'\\x01'")
  inspect!(section.length(), content="5")
}
