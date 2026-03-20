/// Wasm Global Section のエンコーダ
/// グローバル変数（スタックポインタ等）の宣言を行う

/// グローバル変数の mutability フラグ
pub(all) enum Mutability {
  Immutable // 0x00
  Mutable   // 0x01
} derive(Show)

/// Mutability を対応するバイト値に変換する
pub fn Mutability::to_byte(self : Mutability) -> Byte {
  match self {
    Immutable => b'\x00'
    Mutable => b'\x01'
  }
}

/// グローバル変数の型定義
/// valtype + mutability
pub(all) struct GlobalType {
  valtype : ValType
  mutability : Mutability
} derive(Show)

/// グローバル変数のエントリ
/// global_type + init_expr（定数式）
pub(all) struct GlobalEntry {
  global_type : GlobalType
  init_expr : Array[Byte]
} derive(Show)

/// GlobalType をバイト列にエンコードする
/// フォーマット: valtype(1 byte) + mutability(1 byte)
pub fn encode_global_type(gt : GlobalType) -> Array[Byte] {
  [gt.valtype.to_byte(), gt.mutability.to_byte()]
}

/// 単一の GlobalEntry をバイト列にエンコードする
/// フォーマット: global_type + init_expr(定数式 + 0x0B end)
fn encode_global_entry(entry : GlobalEntry) -> Array[Byte] {
  let result : Array[Byte] = Array::new(
    capacity=2 + entry.init_expr.length(),
  )
  // global_type
  let gt_bytes = encode_global_type(entry.global_type)
  for b in gt_bytes {
    result.push(b)
  }
  // init_expr（呼び出し側で end バイト 0x0B を含めること）
  for b in entry.init_expr {
    result.push(b)
  }
  result
}

/// i32.const の定数式を生成する（init_expr 用）
/// フォーマット: 0x41 + value(sleb128) + 0x0B(end)
pub fn make_i32_const_expr(value : Int) -> Array[Byte] {
  let result : Array[Byte] = Array::new(capacity=8)
  result.push(b'\x41') // i32.const
  let bytes = encode_sleb128(value)
  for b in bytes {
    result.push(b)
  }
  result.push(b'\x0B') // end
  result
}

/// Global Section 全体をエンコードする
/// フォーマット: section_id(0x06) + size(uleb128) + count(uleb128) + global_entry*
pub fn encode_global_section(globals : Array[GlobalEntry]) -> Array[Byte] {
  let payload : Array[Byte] = Array::new(capacity=16)
  // グローバル変数の個数
  let count_bytes = encode_uleb128(globals.length())
  for b in count_bytes {
    payload.push(b)
  }
  // 各グローバル変数のエントリ
  for entry in globals {
    let entry_bytes = encode_global_entry(entry)
    for b in entry_bytes {
      payload.push(b)
    }
  }
  encode_section(SecGlobal, payload)
}
