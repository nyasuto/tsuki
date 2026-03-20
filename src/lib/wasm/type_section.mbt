/// Wasm Type Section のエンコーダ

/// Wasm の値型
pub(all) enum ValType {
  I32  // 0x7F
  I64  // 0x7E
} derive(Show, Eq)

/// ValType を対応するバイト値に変換する
pub fn to_byte(self : ValType) -> Byte {
  match self {
    I32 => b'\x7F'
    I64 => b'\x7E'
  }
}

/// Wasm の関数シグネチャ
pub(all) struct FuncType {
  params : Array[ValType]
  results : Array[ValType]
} derive(Show, Eq)

/// 単一の関数シグネチャをバイト列にエンコードする
/// フォーマット: 0x60 + param_count(uleb128) + param_types + result_count(uleb128) + result_types
pub fn encode_func_type(ft : FuncType) -> Array[Byte] {
  let result : Array[Byte] = Array::new(capacity=8)
  // functype マーカー
  result.push(b'\x60')
  // パラメータ
  let param_count = encode_uleb128(ft.params.length())
  for b in param_count {
    result.push(b)
  }
  for p in ft.params {
    result.push(p.to_byte())
  }
  // 戻り値
  let result_count = encode_uleb128(ft.results.length())
  for b in result_count {
    result.push(b)
  }
  for r in ft.results {
    result.push(r.to_byte())
  }
  result
}

/// Type Section 全体をエンコードする
/// フォーマット: section_id(0x01) + size(uleb128) + count(uleb128) + functype*
pub fn encode_type_section(func_types : Array[FuncType]) -> Array[Byte] {
  let payload : Array[Byte] = Array::new(capacity=32)
  // 関数型の個数
  let count_bytes = encode_uleb128(func_types.length())
  for b in count_bytes {
    payload.push(b)
  }
  // 各関数型をエンコード
  for ft in func_types {
    let encoded = encode_func_type(ft)
    for b in encoded {
      payload.push(b)
    }
  }
  encode_section(SecType, payload)
}
