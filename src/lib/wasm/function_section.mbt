/// Wasm Function Section のエンコーダ
/// 各関数を Type Section 内のシグネチャインデックスにマッピングする

/// Function Section 全体をエンコードする
/// フォーマット: section_id(0x03) + size(uleb128) + count(uleb128) + type_idx*
/// type_indices: 各関数に対応する Type Section 内のインデックス（uleb128）
pub fn encode_function_section(type_indices : Array[Int]) -> Array[Byte] {
  let payload : Array[Byte] = Array::new(capacity=1 + type_indices.length())
  // 関数の個数
  let count_bytes = encode_uleb128(type_indices.length())
  for b in count_bytes {
    payload.push(b)
  }
  // 各関数の type index
  for idx in type_indices {
    let idx_bytes = encode_uleb128(idx)
    for b in idx_bytes {
      payload.push(b)
    }
  }
  encode_section(SecFunction, payload)
}
