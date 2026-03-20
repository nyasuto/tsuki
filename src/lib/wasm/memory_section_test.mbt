test "encode_memory_section: single memory with min only (1 page)" {
  // 1ページの線形メモリ（min のみ指定）
  let section = encode_memory_section([LimitsMin(1)])
  // Section id: 0x05 (Memory)
  inspect!(section[0], content="b'\\x05'")
  // Payload size: 3 bytes (count(1) + flags(1) + min(1))
  inspect!(section[1], content="b'\\x03'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // Limits flags: 0x00 (min only)
  inspect!(section[3], content="b'\\x00'")
  // Min pages: 1
  inspect!(section[4], content="b'\\x01'")
  inspect!(section.length(), content="5")
}

test "encode_memory_section: single memory with min and max" {
  // min=1, max=10 の線形メモリ
  let section = encode_memory_section([LimitsMinMax(1, 10)])
  // Section id: 0x05
  inspect!(section[0], content="b'\\x05'")
  // Payload size: 4 bytes (count(1) + flags(1) + min(1) + max(1))
  inspect!(section[1], content="b'\\x04'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // Limits flags: 0x01 (min + max)
  inspect!(section[3], content="b'\\x01'")
  // Min pages: 1
  inspect!(section[4], content="b'\\x01'")
  // Max pages: 10
  inspect!(section[5], content="b'\\x0A'")
  inspect!(section.length(), content="6")
}

test "encode_memory_section: empty" {
  let section = encode_memory_section([])
  // Section id: 0x05 + size: 0x01 + count: 0x00
  inspect!(section, content="[b'\\x05', b'\\x01', b'\\x00']")
}

test "encode_limits: min only" {
  let bytes = encode_limits(LimitsMin(4))
  // flags: 0x00, min: 4
  inspect!(bytes, content="[b'\\x00', b'\\x04']")
}

test "encode_limits: min and max" {
  let bytes = encode_limits(LimitsMinMax(1, 256))
  // flags: 0x01, min: 1, max: 256 (uleb128: 0x80 0x02)
  inspect!(bytes[0], content="b'\\x01'")
  inspect!(bytes[1], content="b'\\x01'")
  inspect!(bytes[2], content="b'\\x80'")
  inspect!(bytes[3], content="b'\\x02'")
  inspect!(bytes.length(), content="4")
}
