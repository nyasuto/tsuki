/// Wasm Memory Section のエンコーダ
/// 線形メモリの宣言（ページ数の指定）を行う

/// Wasm limits のフラグ
/// 0x00: min のみ指定、0x01: min + max を指定
pub(all) enum Limits {
  LimitsMin(Int)
  LimitsMinMax(Int, Int)
}

/// Limits をバイト列にエンコードする
/// LimitsMin(min): 0x00 + min(uleb128)
/// LimitsMinMax(min, max): 0x01 + min(uleb128) + max(uleb128)
pub fn encode_limits(limits : Limits) -> Array[Byte] {
  match limits {
    LimitsMin(min) => {
      let result : Array[Byte] = Array::new(capacity=2)
      result.push(b'\x00')
      let min_bytes = encode_uleb128(min)
      for b in min_bytes {
        result.push(b)
      }
      result
    }
    LimitsMinMax(min, max) => {
      let result : Array[Byte] = Array::new(capacity=4)
      result.push(b'\x01')
      let min_bytes = encode_uleb128(min)
      for b in min_bytes {
        result.push(b)
      }
      let max_bytes = encode_uleb128(max)
      for b in max_bytes {
        result.push(b)
      }
      result
    }
  }
}

/// Memory Section 全体をエンコードする
/// フォーマット: section_id(0x05) + size(uleb128) + count(uleb128) + mem_type*
/// mem_type: limits（線形メモリのページ数制約）
pub fn encode_memory_section(memories : Array[Limits]) -> Array[Byte] {
  let payload : Array[Byte] = Array::new(capacity=8)
  // メモリの個数
  let count_bytes = encode_uleb128(memories.length())
  for b in count_bytes {
    payload.push(b)
  }
  // 各メモリの limits
  for mem in memories {
    let limits_bytes = encode_limits(mem)
    for b in limits_bytes {
      payload.push(b)
    }
  }
  encode_section(SecMemory, payload)
}
