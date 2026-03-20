/// Parser: Token 列から AST を構築する
pub(all) struct Parser {
  tokens : Array[@lexer.LocToken]
  mut pos : Int
}

/// Parser を生成する
pub fn Parser::new(tokens : Array[@lexer.LocToken]) -> Parser {
  { tokens, pos: 0 }
}

/// 現在のトークンを返す（消費しない）
pub fn Parser::peek(self : Parser) -> @lexer.Token {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos].token
  } else {
    @lexer.Token::Eof
  }
}

/// 現在の位置情報付きトークンを返す（消費しない）
fn Parser::peek_loc(self : Parser) -> @lexer.LocToken {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos]
  } else {
    { token: @lexer.Token::Eof, pos: { line: 0, col: 0 } }
  }
}

/// 現在のトークンを消費して返す
pub fn Parser::advance(self : Parser) -> @lexer.Token {
  let tok = self.peek()
  if self.pos < self.tokens.length() {
    self.pos += 1
  }
  tok
}

/// 期待するトークンを消費する。一致しなければエラーを返す
pub fn Parser::expect(
  self : Parser,
  expected : @lexer.Token
) -> Result[Unit, String] {
  let loc = self.peek_loc()
  let actual = self.advance()
  if actual == expected {
    Ok(())
  } else {
    let pos = loc.pos
    Err(
      "expected \{expected}, got \{actual} at line \{pos.line}, col \{pos.col}",
    )
  }
}

/// 現在のトークンが指定したトークンと一致するか確認する
fn Parser::check(self : Parser, expected : @lexer.Token) -> Bool {
  self.peek() == expected
}

/// EOF に到達したか確認する
fn Parser::at_eof(self : Parser) -> Bool {
  self.peek() == @lexer.Token::Eof
}

/// 現在の位置情報を返す
fn Parser::current_pos(self : Parser) -> @lexer.Pos {
  self.peek_loc().pos
}
