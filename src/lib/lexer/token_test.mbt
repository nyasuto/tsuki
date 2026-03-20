test "keyword tokens derive Show" {
  inspect(Token::KwInt, content="KwInt")
  inspect(Token::KwChar, content="KwChar")
  inspect(Token::KwVoid, content="KwVoid")
  inspect(Token::KwStruct, content="KwStruct")
  inspect(Token::KwIf, content="KwIf")
  inspect(Token::KwElse, content="KwElse")
  inspect(Token::KwWhile, content="KwWhile")
  inspect(Token::KwFor, content="KwFor")
  inspect(Token::KwReturn, content="KwReturn")
  inspect(Token::KwSizeof, content="KwSizeof")
  inspect(Token::Eof, content="Eof")
}

test "LocToken with position" {
  let tok = LocToken::{ token: KwReturn, pos: { line: 1, col: 5 } }
  inspect(tok, content="{token: KwReturn, pos: {line: 1, col: 5}}")
}
