test "encode_module_header returns 8 bytes" {
  let header = encode_module_header()
  inspect!(header.length(), content="8")
}

test "encode_module_header magic number" {
  let header = encode_module_header()
  // magic number: \0asm (0x00, 0x61, 0x73, 0x6D)
  inspect!(header[0], content="b'\\x00'")
  inspect!(header[1], content="b'\\x61'")
  inspect!(header[2], content="b'\\x73'")
  inspect!(header[3], content="b'\\x6D'")
}

test "encode_module_header version" {
  let header = encode_module_header()
  // version: 1 (0x01, 0x00, 0x00, 0x00)
  inspect!(header[4], content="b'\\x01'")
  inspect!(header[5], content="b'\\x00'")
  inspect!(header[6], content="b'\\x00'")
  inspect!(header[7], content="b'\\x00'")
}

test "SectionId to_byte" {
  inspect!(SectionId::SecCustom.to_byte(), content="b'\\x00'")
  inspect!(SectionId::SecType.to_byte(), content="b'\\x01'")
  inspect!(SectionId::SecImport.to_byte(), content="b'\\x02'")
  inspect!(SectionId::SecFunction.to_byte(), content="b'\\x03'")
  inspect!(SectionId::SecTable.to_byte(), content="b'\\x04'")
  inspect!(SectionId::SecMemory.to_byte(), content="b'\\x05'")
  inspect!(SectionId::SecGlobal.to_byte(), content="b'\\x06'")
  inspect!(SectionId::SecExport.to_byte(), content="b'\\x07'")
  inspect!(SectionId::SecStart.to_byte(), content="b'\\x08'")
  inspect!(SectionId::SecElement.to_byte(), content="b'\\x09'")
  inspect!(SectionId::SecCode.to_byte(), content="b'\\x0A'")
  inspect!(SectionId::SecData.to_byte(), content="b'\\x0B'")
}

test "encode_section with empty payload" {
  let section = encode_section(SecType, [])
  // Type section id (0x01) + size 0 (0x00)
  inspect!(section.length(), content="2")
  inspect!(section[0], content="b'\\x01'")
  inspect!(section[1], content="b'\\x00'")
}

test "encode_section with payload" {
  // 3バイトのペイロードを持つ Memory セクション
  let payload : Array[Byte] = [b'\x01', b'\x00', b'\x01']
  let section = encode_section(SecMemory, payload)
  // Memory section id (0x05) + size 3 (0x03) + payload (3 bytes)
  inspect!(section.length(), content="5")
  inspect!(section[0], content="b'\\x05'")
  inspect!(section[1], content="b'\\x03'")
  inspect!(section[2], content="b'\\x01'")
  inspect!(section[3], content="b'\\x00'")
  inspect!(section[4], content="b'\\x01'")
}

test "encode_section with large payload" {
  // 128バイト以上のペイロード（サイズが2バイトのuleb128になる）
  let payload : Array[Byte] = Array::new(capacity=200)
  for i = 0; i < 200; i = i + 1 {
    payload.push(b'\x42')
  }
  let section = encode_section(SecCode, payload)
  // Code section id (0x0A) + size 200 (uleb128: 0xC8 0x01) + payload (200 bytes)
  inspect!(section.length(), content="203")
  inspect!(section[0], content="b'\\x0A'")
  // 200 = 0xC8 in uleb128: (200 & 0x7F) | 0x80 = 0xC8, 200 >> 7 = 1 → 0x01
  inspect!(section[1], content="b'\\xC8'")
  inspect!(section[2], content="b'\\x01'")
  inspect!(section[3], content="b'\\x42'")
}
