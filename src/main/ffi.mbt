/// C FFI: ファイル読み込み（UTF-8 テキストファイルを MoonBit String として返す）
/// 失敗時は空文字列を返す（NULL は MoonBit 側で空文字列になる）
#cfg(target="native")
#owned(path)
extern "C" fn mucc_read_file(path : Bytes) -> String = "mucc_read_file"

/// C FFI: バイナリデータをファイルに書き出す
/// 成功時は 0、失敗時は -1 を返す
#cfg(target="native")
#owned(path, data)
extern "C" fn mucc_write_file(path : Bytes, data : Bytes) -> Int = "mucc_write_file"

/// String を null 終端の UTF-8 バイト列に変換する（C のファイルパス用）
/// ASCII 文字のみを想定
fn string_to_cstr(s : String) -> Bytes {
  let len = s.length()
  let arr : Array[Byte] = Array::new(capacity=len + 1)
  for i = 0; i < len; i = i + 1 {
    arr.push(s[i].to_int().land(0xFF).to_byte())
  }
  arr.push(b'\x00') // null 終端
  Bytes::from_array(arr)
}

/// Array[Byte] を Bytes に変換する
fn array_byte_to_bytes(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(arr)
}
