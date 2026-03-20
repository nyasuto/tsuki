/// 文字列プール: 文字列リテラルを収集しメモリアドレスを割り当てる
/// 同一文字列は同じアドレスを共有する（重複排除）

/// 文字列プール
pub struct StringPool {
  /// 文字列 → メモリアドレスのマッピング
  strings : Map[String, Int]
  /// 次の文字列の配置オフセット
  mut next_offset : Int
  /// 文字列エントリ（登録順）
  entries : Array[(String, Int)]
}

/// 新しい文字列プールを作成する
pub fn StringPool::new() -> StringPool {
  { strings: {}, next_offset: 0, entries: [] }
}

/// 文字列をプールに登録し、メモリアドレスを返す
/// 同じ文字列が既に登録されていれば既存のアドレスを返す
pub fn StringPool::add(self : StringPool, s : String) -> Int {
  match self.strings.get(s) {
    Some(addr) => addr
    None => {
      let addr = self.next_offset
      self.strings[s] = addr
      self.entries.push((s, addr))
      // 文字列のバイト数 + null 終端
      self.next_offset += string_byte_length(s) + 1
      addr
    }
  }
}

/// 文字列プールの合計バイトサイズを返す
pub fn StringPool::total_size(self : StringPool) -> Int {
  self.next_offset
}

/// 文字列プールが空かどうかを返す
pub fn StringPool::is_empty(self : StringPool) -> Bool {
  self.entries.is_empty()
}

/// 文字列プールから Wasm DataSegment の配列を生成する
pub fn StringPool::to_data_segments(
  self : StringPool
) -> Array[@wasm.DataSegment] {
  if self.entries.is_empty() {
    return []
  }
  // 全文字列を1つの連続したセグメントにまとめる
  let data : Array[Byte] = Array::new(capacity=self.next_offset)
  for entry in self.entries {
    let (s, _) = entry
    let bytes = string_to_bytes(s)
    for b in bytes {
      data.push(b)
    }
  }
  [{ offset: 0, data }]
}

/// MoonBit 文字列をバイト列に変換する（null 終端付き）
/// レキサーでエスケープ処理済みの文字列を ASCII バイト列に変換する
fn string_to_bytes(s : String) -> Array[Byte] {
  let bytes : Array[Byte] = Array::new(capacity=s.length() + 1)
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    bytes.push(ch.to_int().to_byte())
  }
  bytes.push(b'\x00') // null 終端
  bytes
}

/// 文字列のバイト数を返す（null 終端は含まない）
fn string_byte_length(s : String) -> Int {
  // ASCII 前提: 1文字 = 1バイト
  s.length()
}
