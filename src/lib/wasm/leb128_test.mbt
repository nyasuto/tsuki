// === 符号なし LEB128 テスト ===

test "encode_uleb128: 0" {
  inspect(@wasm.encode_uleb128(0), content="[b'\\x00']")
}

test "encode_uleb128: 1" {
  inspect(@wasm.encode_uleb128(1), content="[b'\\x01']")
}

test "encode_uleb128: 127 (0x7F) は 1 バイト" {
  inspect(@wasm.encode_uleb128(127), content="[b'\\x7F']")
}

test "encode_uleb128: 128 (0x80) は 2 バイト" {
  inspect(@wasm.encode_uleb128(128), content="[b'\\x80', b'\\x01']")
}

test "encode_uleb128: 624485 は Wasm 仕様の例" {
  // 624485 = 0x98765 → LEB128: [0xE5, 0x8E, 0x26]
  inspect(
    @wasm.encode_uleb128(624485),
    content="[b'\\xE5', b'\\x8E', b'\\x26']",
  )
}

test "encode_uleb128: 255" {
  // 255 = 0xFF → LEB128: [0xFF, 0x01]
  inspect(@wasm.encode_uleb128(255), content="[b'\\xFF', b'\\x01']")
}

test "encode_uleb128: 256" {
  // 256 = 0x100 → LEB128: [0x80, 0x02]
  inspect(@wasm.encode_uleb128(256), content="[b'\\x80', b'\\x02']")
}

test "encode_uleb128: 大きい値 16384" {
  // 16384 = 0x4000 → LEB128: [0x80, 0x80, 0x01]
  inspect(
    @wasm.encode_uleb128(16384),
    content="[b'\\x80', b'\\x80', b'\\x01']",
  )
}

// === 符号付き LEB128 テスト ===

test "encode_sleb128: 0" {
  inspect(@wasm.encode_sleb128(0), content="[b'\\x00']")
}

test "encode_sleb128: 1" {
  inspect(@wasm.encode_sleb128(1), content="[b'\\x01']")
}

test "encode_sleb128: -1" {
  inspect(@wasm.encode_sleb128(-1), content="[b'\\x7F']")
}

test "encode_sleb128: 63 は 1 バイト（正の最大）" {
  inspect(@wasm.encode_sleb128(63), content="[b'\\x3F']")
}

test "encode_sleb128: 64 は 2 バイト" {
  inspect(@wasm.encode_sleb128(64), content="[b'\\xC0', b'\\x00']")
}

test "encode_sleb128: -64 は 1 バイト（負の最小）" {
  inspect(@wasm.encode_sleb128(-64), content="[b'\\x40']")
}

test "encode_sleb128: -65 は 2 バイト" {
  inspect(@wasm.encode_sleb128(-65), content="[b'\\xBF', b'\\x7F']")
}

test "encode_sleb128: 128" {
  // 128 → [0x80, 0x01]
  inspect(@wasm.encode_sleb128(128), content="[b'\\x80', b'\\x01']")
}

test "encode_sleb128: -128" {
  // -128 → [0x80, 0x7F]
  inspect(@wasm.encode_sleb128(-128), content="[b'\\x80', b'\\x7F']")
}

test "encode_sleb128: -123456 は Wasm 仕様例に近い値" {
  // -123456 → LEB128: [0xC0, 0xBB, 0x78]
  inspect(
    @wasm.encode_sleb128(-123456),
    content="[b'\\xC0', b'\\xBB', b'\\x78']",
  )
}
