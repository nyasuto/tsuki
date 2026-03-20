/// Wasm バイナリモジュールのエンコーダ

/// Wasm バイナリのマジックナンバー: '\0asm'
let wasm_magic : FixedArray[Byte] = [b'\x00', b'\x61', b'\x73', b'\x6D']

/// Wasm バイナリのバージョン: 1
let wasm_version : FixedArray[Byte] = [b'\x01', b'\x00', b'\x00', b'\x00']

/// Wasm モジュールヘッダ（magic number + version）をバイト列として返す
pub fn encode_module_header() -> Array[Byte] {
  let result : Array[Byte] = Array::new(capacity=8)
  for b in wasm_magic {
    result.push(b)
  }
  for b in wasm_version {
    result.push(b)
  }
  result
}

/// Wasm セクション ID
pub(all) enum SectionId {
  SecCustom    // 0
  SecType      // 1
  SecImport    // 2
  SecFunction  // 3
  SecTable     // 4
  SecMemory    // 5
  SecGlobal    // 6
  SecExport    // 7
  SecStart     // 8
  SecElement   // 9
  SecCode      // 10
  SecData      // 11
} derive(Show)

/// SectionId を対応するバイト値に変換する
pub fn to_byte(self : SectionId) -> Byte {
  match self {
    SecCustom => b'\x00'
    SecType => b'\x01'
    SecImport => b'\x02'
    SecFunction => b'\x03'
    SecTable => b'\x04'
    SecMemory => b'\x05'
    SecGlobal => b'\x06'
    SecExport => b'\x07'
    SecStart => b'\x08'
    SecElement => b'\x09'
    SecCode => b'\x0A'
    SecData => b'\x0B'
  }
}

/// Wasm セクションをエンコードする汎用関数
/// フォーマット: section_id (1 byte) + payload_size (uleb128) + payload (bytes)
pub fn encode_section(id : SectionId, payload : Array[Byte]) -> Array[Byte] {
  let size_bytes = encode_uleb128(payload.length())
  let result : Array[Byte] = Array::new(
    capacity=1 + size_bytes.length() + payload.length(),
  )
  result.push(id.to_byte())
  for b in size_bytes {
    result.push(b)
  }
  for b in payload {
    result.push(b)
  }
  result
}
