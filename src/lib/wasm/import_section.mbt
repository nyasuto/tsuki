/// Wasm Import Section のエンコーダ
/// 外部モジュールから関数やメモリをインポートする

/// インポートの種類
pub(all) enum ImportDesc {
  /// 関数インポート: type index を指定
  ImportFunc(Int)
} derive(Show)

/// インポートエントリ
pub(all) struct ImportEntry {
  module_name : String
  field_name : String
  desc : ImportDesc
} derive(Show)

/// 単一のインポートエントリをエンコードする
/// フォーマット: module_name_len + module_name + field_name_len + field_name + import_desc
fn encode_import_entry(entry : ImportEntry) -> Array[Byte] {
  let result : Array[Byte] = Array::new(capacity=32)
  // module name
  let mod_bytes = string_to_utf8(entry.module_name)
  let mod_len = encode_uleb128(mod_bytes.length())
  for b in mod_len {
    result.push(b)
  }
  for b in mod_bytes {
    result.push(b)
  }
  // field name
  let field_bytes = string_to_utf8(entry.field_name)
  let field_len = encode_uleb128(field_bytes.length())
  for b in field_len {
    result.push(b)
  }
  for b in field_bytes {
    result.push(b)
  }
  // import descriptor
  match entry.desc {
    ImportFunc(type_index) => {
      result.push(b'\x00') // 0x00 = func
      let idx = encode_uleb128(type_index)
      for b in idx {
        result.push(b)
      }
    }
  }
  result
}

/// Import Section 全体をエンコードする
/// フォーマット: section_id(0x02) + size(uleb128) + count(uleb128) + import_entry*
pub fn encode_import_section(imports : Array[ImportEntry]) -> Array[Byte] {
  let payload : Array[Byte] = Array::new(capacity=64)
  // インポートの個数
  let count_bytes = encode_uleb128(imports.length())
  for b in count_bytes {
    payload.push(b)
  }
  // 各インポートエントリ
  for entry in imports {
    let entry_bytes = encode_import_entry(entry)
    for b in entry_bytes {
      payload.push(b)
    }
  }
  encode_section(SecImport, payload)
}
