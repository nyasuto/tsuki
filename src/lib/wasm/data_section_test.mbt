test "encode_data_section: 単一セグメント" {
  let segments : Array[@wasm.DataSegment] = [
    { offset: 0, data: [b'\x48', b'\x65', b'\x6C', b'\x6C', b'\x6F', b'\x00'] },
  ]
  let result = @wasm.encode_data_section(segments)
  let hex = bytes_to_hex(result)
  inspect!(
    hex,
    content=
      #|0b 0c 01 00 41 00 0b 06 48 65 6c 6c 6f 00
    ,
  )
}

test "encode_data_section: 複数セグメント" {
  let segments : Array[@wasm.DataSegment] = [
    { offset: 0, data: [b'\x41', b'\x42', b'\x00'] }, // "AB\0"
    { offset: 3, data: [b'\x43', b'\x44', b'\x00'] }, // "CD\0"
  ]
  let result = @wasm.encode_data_section(segments)
  let hex = bytes_to_hex(result)
  inspect!(
    hex,
    content=
      #|0b 11 02 00 41 00 0b 03 41 42 00 00 41 03 0b 03 43 44 00
    ,
  )
}

test "encode_data_section: 空セグメント" {
  let segments : Array[@wasm.DataSegment] = []
  let result = @wasm.encode_data_section(segments)
  let hex = bytes_to_hex(result)
  inspect!(
    hex,
    content=
      #|0b 01 00
    ,
  )
}

/// バイト列を16進数文字列に変換する（テスト用）
fn bytes_to_hex(bytes : Array[Byte]) -> String {
  let buf = StringBuilder::new(size_hint=bytes.length() * 3)
  for i, b in bytes {
    if i > 0 {
      buf.write_char(' ')
    }
    let n = b.to_int()
    let hi = n / 16
    let lo = n % 16
    buf.write_char(hex_digit(hi))
    buf.write_char(hex_digit(lo))
  }
  buf.to_string()
}

fn hex_digit(n : Int) -> Char {
  if n < 10 {
    Char::from_int(n + 48)
  } else {
    Char::from_int(n - 10 + 97)
  }
}
