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
