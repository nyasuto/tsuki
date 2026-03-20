/// LEB128 エンコーディング: Wasm バイナリで使用される可変長整数エンコーディング

/// 符号なし LEB128 エンコード
/// value は非負の整数であること
pub fn encode_uleb128(value : Int) -> Array[Byte] {
  let result : Array[Byte] = []
  let mut v = value
  while true {
    let byte_val = v.land(0x7F)
    v = (v.reinterpret_as_uint() >> 7).reinterpret_as_int()
    if v != 0 {
      result.push(byte_val.lor(0x80).to_byte())
    } else {
      result.push(byte_val.to_byte())
      break
    }
  }
  result
}

/// 符号付き LEB128 エンコード
pub fn encode_sleb128(value : Int) -> Array[Byte] {
  let result : Array[Byte] = []
  let mut v = value
  let mut more = true
  while more {
    let byte_val = v.land(0x7F)
    v = v >> 7
    if (v == 0 && byte_val.land(0x40) == 0) ||
      (v == -1 && byte_val.land(0x40) != 0) {
      more = false
      result.push(byte_val.to_byte())
    } else {
      result.push(byte_val.lor(0x80).to_byte())
    }
  }
  result
}
