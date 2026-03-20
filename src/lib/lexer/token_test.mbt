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

test "operator tokens derive Show" {
  inspect(Token::Plus, content="Plus")
  inspect(Token::Minus, content="Minus")
  inspect(Token::Star, content="Star")
  inspect(Token::Slash, content="Slash")
  inspect(Token::Percent, content="Percent")
  inspect(Token::Eq, content="Eq")
  inspect(Token::Ne, content="Ne")
  inspect(Token::Lt, content="Lt")
  inspect(Token::Gt, content="Gt")
  inspect(Token::Le, content="Le")
  inspect(Token::Ge, content="Ge")
  inspect(Token::And, content="And")
  inspect(Token::Or, content="Or")
  inspect(Token::Amp, content="Amp")
  inspect(Token::Pipe, content="Pipe")
  inspect(Token::Caret, content="Caret")
  inspect(Token::Shl, content="Shl")
  inspect(Token::Shr, content="Shr")
  inspect(Token::Bang, content="Bang")
  inspect(Token::Tilde, content="Tilde")
  inspect(Token::Inc, content="Inc")
  inspect(Token::Dec, content="Dec")
  inspect(Token::Assign, content="Assign")
}

test "literal and identifier tokens derive Show" {
  inspect(Token::IntLit(42), content="IntLit(42)")
  inspect(Token::IntLit(0), content="IntLit(0)")
  inspect(Token::CharLit('a'), content="CharLit('a')")
  inspect(Token::CharLit('\n'), content="CharLit('\\n')")
  inspect(Token::StringLit("hello"), content="StringLit(\"hello\")")
  inspect(Token::StringLit(""), content="StringLit(\"\")")
  inspect(Token::Ident("main"), content="Ident(\"main\")")
  inspect(Token::Ident("x"), content="Ident(\"x\")")
}

test "LocToken with literal token" {
  let tok = LocToken::{ token: IntLit(42), pos: { line: 3, col: 10 } }
  inspect(tok, content="{token: IntLit(42), pos: {line: 3, col: 10}}")
}

test "LocToken with position" {
  let tok = LocToken::{ token: KwReturn, pos: { line: 1, col: 5 } }
  inspect(tok, content="{token: KwReturn, pos: {line: 1, col: 5}}")
}
