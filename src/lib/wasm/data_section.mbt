/// Wasm Data Section のエンコーダ
/// 線形メモリへの初期データ（文字列リテラル等）の埋め込みを行う

/// データセグメント: メモリの指定オフセットにデータを配置する
pub(all) struct DataSegment {
  /// メモリ内のオフセット（定数式で指定）
  offset : Int
  /// 埋め込むバイト列
  data : Array[Byte]
} derive(Show)

/// Data Section 全体をエンコードする
/// フォーマット: section_id(0x0B) + size(uleb128) + count(uleb128) + data_segment*
/// 各 data_segment: 0x00 + offset_expr(i32.const + end) + size(uleb128) + data
pub fn encode_data_section(segments : Array[DataSegment]) -> Array[Byte] {
  let payload : Array[Byte] = Array::new(capacity=64)
  // セグメント数
  let count_bytes = encode_uleb128(segments.length())
  for b in count_bytes {
    payload.push(b)
  }
  // 各セグメント
  for seg in segments {
    // memory index: 0x00（アクティブセグメント、memory 0）
    payload.push(b'\x00')
    // offset expr: i32.const <offset> end
    let offset_expr = make_i32_const_expr(seg.offset)
    for b in offset_expr {
      payload.push(b)
    }
    // data size
    let size_bytes = encode_uleb128(seg.data.length())
    for b in size_bytes {
      payload.push(b)
    }
    // data bytes
    for b in seg.data {
      payload.push(b)
    }
  }
  encode_section(SecData, payload)
}
