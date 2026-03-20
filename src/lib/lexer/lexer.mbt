/// Lexer: C ソースコードを Token 列に変換する字句解析器
pub(all) struct Lexer {
  src : String
  mut pos : Int    // 現在の読み取り位置（バイトインデックス）
  mut line : Int   // 現在の行番号（1始まり）
  mut col : Int    // 現在の列番号（1始まり）
}

/// Lexer を生成する
pub fn Lexer::new(src : String) -> Lexer {
  { src, pos: 0, line: 1, col: 1 }
}

/// 現在位置の文字を返す（終端なら None）
pub fn Lexer::peek(self : Lexer) -> Char? {
  if self.pos >= self.src.length() {
    None
  } else {
    Some(self.src[self.pos].to_int().unsafe_to_char())
  }
}

/// 現在位置から n 文字先の文字を返す（範囲外なら None）
pub fn Lexer::peek_ahead(self : Lexer, n : Int) -> Char? {
  let idx = self.pos + n
  if idx >= self.src.length() {
    None
  } else {
    Some(self.src[idx].to_int().unsafe_to_char())
  }
}

/// 現在位置の文字を消費して返す（終端なら None）
pub fn Lexer::advance(self : Lexer) -> Char? {
  if self.pos >= self.src.length() {
    None
  } else {
    let ch = self.src[self.pos].to_int().unsafe_to_char()
    self.pos += 1
    if ch == '\n' {
      self.line += 1
      self.col = 1
    } else {
      self.col += 1
    }
    Some(ch)
  }
}

/// 現在のソース位置を返す
pub fn Lexer::current_pos(self : Lexer) -> Pos {
  { line: self.line, col: self.col }
}

/// 入力の終端に達したかどうか
pub fn Lexer::is_eof(self : Lexer) -> Bool {
  self.pos >= self.src.length()
}

/// 文字が10進数字かどうか
fn is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

/// 整数リテラルをスキャンする（現在位置が数字であること前提）
fn Lexer::scan_int_lit(self : Lexer) -> Token {
  let mut value = 0
  while not(self.is_eof()) {
    match self.peek() {
      Some(ch) =>
        if is_digit(ch) {
          value = value * 10 + (ch.to_int() - '0'.to_int())
          let _ = self.advance()
        } else {
          break
        }
      None => break
    }
  }
  Token::IntLit(value)
}

/// 次のトークンを読み取る
pub fn Lexer::next_token(self : Lexer) -> Result[LocToken, String] {
  if self.is_eof() {
    let pos = self.current_pos()
    return Ok(LocToken::{ token: Token::Eof, pos })
  }
  let pos = self.current_pos()
  match self.peek() {
    Some(ch) =>
      if is_digit(ch) {
        let token = self.scan_int_lit()
        Ok(LocToken::{ token, pos })
      } else {
        Err("unexpected character '\{ch}' at line \{pos.line}, col \{pos.col}")
      }
    None => Ok(LocToken::{ token: Token::Eof, pos })
  }
}

/// 全トークンを読み取る
pub fn Lexer::tokenize(self : Lexer) -> Result[Array[LocToken], String] {
  let tokens : Array[LocToken] = []
  while true {
    match self.next_token() {
      Ok(loc_token) => {
        tokens.push(loc_token)
        if loc_token.token == Token::Eof {
          break
        }
      }
      Err(e) => return Err(e)
    }
  }
  Ok(tokens)
}
