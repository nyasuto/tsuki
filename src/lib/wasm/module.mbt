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
