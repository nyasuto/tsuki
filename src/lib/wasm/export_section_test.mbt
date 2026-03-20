test "encode_export_section: export main function" {
  // main 関数（function index 0）をエクスポート
  let section = encode_export_section(
    [{ name: "_start", kind: ExportFunc, index: 0 }],
  )
  // Section id: 0x07 (Export)
  inspect!(section[0], content="b'\\x07'")
  // Payload: count(1) + name_len(1) + "_start"(6) + kind(1) + index(1) = 10 bytes
  inspect!(section[1], content="b'\\x0A'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // Name length: 6
  inspect!(section[3], content="b'\\x06'")
  // Name: "_start" (ASCII)
  inspect!(section[4], content="b'\\x5F'") // '_'
  inspect!(section[5], content="b'\\x73'") // 's'
  inspect!(section[6], content="b'\\x74'") // 't'
  inspect!(section[7], content="b'\\x61'") // 'a'
  inspect!(section[8], content="b'\\x72'") // 'r'
  inspect!(section[9], content="b'\\x74'") // 't'
  // Kind: 0x00 (function)
  inspect!(section[10], content="b'\\x00'")
  // Index: 0
  inspect!(section[11], content="b'\\x00'")
  inspect!(section.length(), content="12")
}

test "encode_export_section: export memory" {
  // メモリ（memory index 0）をエクスポート
  let section = encode_export_section(
    [{ name: "memory", kind: ExportMem, index: 0 }],
  )
  // Section id: 0x07
  inspect!(section[0], content="b'\\x07'")
  // Payload: count(1) + name_len(1) + "memory"(6) + kind(1) + index(1) = 10 bytes
  inspect!(section[1], content="b'\\x0A'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // Name length: 6
  inspect!(section[3], content="b'\\x06'")
  // Name: "memory"
  inspect!(section[4], content="b'\\x6D'") // 'm'
  inspect!(section[5], content="b'\\x65'") // 'e'
  inspect!(section[6], content="b'\\x6D'") // 'm'
  inspect!(section[7], content="b'\\x6F'") // 'o'
  inspect!(section[8], content="b'\\x72'") // 'r'
  inspect!(section[9], content="b'\\x79'") // 'y'
  // Kind: 0x02 (memory)
  inspect!(section[10], content="b'\\x02'")
  // Index: 0
  inspect!(section[11], content="b'\\x00'")
  inspect!(section.length(), content="12")
}

test "encode_export_section: export function and memory together" {
  // main 関数とメモリを同時にエクスポート
  let section = encode_export_section(
    [
      { name: "_start", kind: ExportFunc, index: 0 },
      { name: "memory", kind: ExportMem, index: 0 },
    ],
  )
  // Section id: 0x07
  inspect!(section[0], content="b'\\x07'")
  // Count: 2 (at offset 2, after section_id + payload_size)
  inspect!(section[2], content="b'\\x02'")
  // 全体のサイズ: section_id(1) + size(1) + payload
  // payload: count(1) + entry1(name_len(1)+"_start"(6)+kind(1)+idx(1)) + entry2(name_len(1)+"memory"(6)+kind(1)+idx(1))
  // = 1 + 9 + 9 = 19 bytes
  inspect!(section[1], content="b'\\x13'")
}

test "encode_export_section: empty exports" {
  let section = encode_export_section([])
  // Section id: 0x07 + size: 0x01 + count: 0x00
  inspect!(section, content="[b'\\x07', b'\\x01', b'\\x00']")
}

test "encode_export_section: export with larger function index" {
  // function index 5 のエクスポート
  let section = encode_export_section(
    [{ name: "add", kind: ExportFunc, index: 5 }],
  )
  // Section id: 0x07
  inspect!(section[0], content="b'\\x07'")
  // Count: 1
  inspect!(section[2], content="b'\\x01'")
  // Name length: 3
  inspect!(section[3], content="b'\\x03'")
  // Name: "add"
  inspect!(section[4], content="b'\\x61'") // 'a'
  inspect!(section[5], content="b'\\x64'") // 'd'
  inspect!(section[6], content="b'\\x64'") // 'd'
  // Kind: 0x00 (function)
  inspect!(section[7], content="b'\\x00'")
  // Index: 5
  inspect!(section[8], content="b'\\x05'")
}

test "encode_export_section: export name encoding verified via main" {
  // "main" という名前の関数エクスポートで文字列エンコーディングを検証
  let section = encode_export_section(
    [{ name: "main", kind: ExportFunc, index: 0 }],
  )
  // Section id: 0x07
  inspect!(section[0], content="b'\\x07'")
  // Name length: 4
  inspect!(section[3], content="b'\\x04'")
  // Name: "main"
  inspect!(section[4], content="b'\\x6D'") // 'm'
  inspect!(section[5], content="b'\\x61'") // 'a'
  inspect!(section[6], content="b'\\x69'") // 'i'
  inspect!(section[7], content="b'\\x6E'") // 'n'
}
