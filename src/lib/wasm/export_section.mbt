/// Wasm Export Section のエンコーダ
/// モジュールの関数やメモリを外部に公開する

/// エクスポート対象の種類
pub(all) enum ExportKind {
  ExportFunc   // 0x00
  ExportTable  // 0x01
  ExportMem    // 0x02
  ExportGlobal // 0x03
} derive(Show)

/// ExportKind を対応するバイト値に変換する
pub fn to_byte(self : ExportKind) -> Byte {
  match self {
    ExportFunc => b'\x00'
    ExportTable => b'\x01'
    ExportMem => b'\x02'
    ExportGlobal => b'\x03'
  }
}

/// エクスポートエントリ
pub(all) struct ExportEntry {
  name : String
  kind : ExportKind
  index : Int
} derive(Show)

/// 単一のエクスポートエントリをエンコードする
/// フォーマット: name_len(uleb128) + name(utf8 bytes) + kind(1 byte) + index(uleb128)
fn encode_export_entry(entry : ExportEntry) -> Array[Byte] {
  let name_bytes = string_to_utf8(entry.name)
  let result : Array[Byte] = Array::new(
    capacity=name_bytes.length() + 2 + 1,
  )
  // 名前の長さ
  let name_len_bytes = encode_uleb128(name_bytes.length())
  for b in name_len_bytes {
    result.push(b)
  }
  // 名前のバイト列
  for b in name_bytes {
    result.push(b)
  }
  // エクスポートの種類
  result.push(entry.kind.to_byte())
  // インデックス
  let idx_bytes = encode_uleb128(entry.index)
  for b in idx_bytes {
    result.push(b)
  }
  result
}

/// 文字列を UTF-8 バイト列に変換する
fn string_to_utf8(s : String) -> Array[Byte] {
  let bytes : Array[Byte] = Array::new(capacity=s.length())
  for ch in s {
    let code = ch.to_int()
    if code <= 0x7F {
      bytes.push(code.to_byte())
    } else if code <= 0x7FF {
      bytes.push((0xC0 | (code >> 6)).to_byte())
      bytes.push((0x80 | (code & 0x3F)).to_byte())
    } else if code <= 0xFFFF {
      bytes.push((0xE0 | (code >> 12)).to_byte())
      bytes.push((0x80 | ((code >> 6) & 0x3F)).to_byte())
      bytes.push((0x80 | (code & 0x3F)).to_byte())
    } else {
      bytes.push((0xF0 | (code >> 18)).to_byte())
      bytes.push((0x80 | ((code >> 12) & 0x3F)).to_byte())
      bytes.push((0x80 | ((code >> 6) & 0x3F)).to_byte())
      bytes.push((0x80 | (code & 0x3F)).to_byte())
    }
  }
  bytes
}

/// Export Section 全体をエンコードする
/// フォーマット: section_id(0x07) + size(uleb128) + count(uleb128) + export_entry*
pub fn encode_export_section(exports : Array[ExportEntry]) -> Array[Byte] {
  let payload : Array[Byte] = Array::new(capacity=16)
  // エクスポートの個数
  let count_bytes = encode_uleb128(exports.length())
  for b in count_bytes {
    payload.push(b)
  }
  // 各エクスポートエントリ
  for entry in exports {
    let entry_bytes = encode_export_entry(entry)
    for b in entry_bytes {
      payload.push(b)
    }
  }
  encode_section(SecExport, payload)
}
