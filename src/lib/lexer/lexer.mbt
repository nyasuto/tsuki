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

/// 文字が識別子の先頭文字として有効かどうか（英字またはアンダースコア）
fn is_alpha(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

/// 文字が識別子の構成文字として有効かどうか（英数字またはアンダースコア）
fn is_alnum(ch : Char) -> Bool {
  is_alpha(ch) || is_digit(ch)
}

/// 文字列がキーワードであればそのトークンを返す
fn lookup_keyword(name : String) -> Token? {
  match name {
    "int" => Some(Token::KwInt)
    "char" => Some(Token::KwChar)
    "void" => Some(Token::KwVoid)
    "struct" => Some(Token::KwStruct)
    "if" => Some(Token::KwIf)
    "else" => Some(Token::KwElse)
    "while" => Some(Token::KwWhile)
    "for" => Some(Token::KwFor)
    "return" => Some(Token::KwReturn)
    "sizeof" => Some(Token::KwSizeof)
    _ => None
  }
}

/// 識別子またはキーワードをスキャンする（現在位置が英字または '_' であること前提）
fn Lexer::scan_ident_or_keyword(self : Lexer) -> Token {
  let buf = StringBuilder::new()
  while not(self.is_eof()) {
    match self.peek() {
      Some(ch) =>
        if is_alnum(ch) {
          buf.write_char(ch)
          let _ = self.advance()
        } else {
          break
        }
      None => break
    }
  }
  let name = buf.to_string()
  match lookup_keyword(name) {
    Some(kw) => kw
    None => Token::Ident(name)
  }
}

/// エスケープシーケンスを解析する（'\\' の直後の文字を受け取る）
fn scan_escape(ch : Char) -> Result[Char, String] {
  match ch {
    'n' => Ok('\n')
    't' => Ok('\t')
    '\\' => Ok('\\')
    '0' => Ok('\u0000')
    '\'' => Ok('\'')
    '"' => Ok('"')
    _ => Err("unknown escape sequence '\\\{ch}'")
  }
}

/// 文字リテラルをスキャンする（現在位置が '\'' であること前提）
fn Lexer::scan_char_lit(self : Lexer) -> Result[Token, String] {
  let start_pos = self.current_pos()
  let _ = self.advance() // 開始の '\'' を消費
  match self.peek() {
    None =>
      Err(
        "unterminated character literal at line \{start_pos.line}, col \{start_pos.col}",
      )
    Some('\'') =>
      Err(
        "empty character literal at line \{start_pos.line}, col \{start_pos.col}",
      )
    Some('\\') => {
      let _ = self.advance() // '\\' を消費
      match self.peek() {
        None =>
          Err(
            "unterminated escape in character literal at line \{start_pos.line}, col \{start_pos.col}",
          )
        Some(esc_ch) => {
          let _ = self.advance() // エスケープ文字を消費
          match scan_escape(esc_ch) {
            Err(e) => Err("\{e} at line \{start_pos.line}, col \{start_pos.col}")
            Ok(ch) =>
              // 閉じの '\'' を確認
              match self.peek() {
                Some('\'') => {
                  let _ = self.advance()
                  Ok(Token::CharLit(ch))
                }
                Some(c) =>
                  Err(
                    "expected closing quote, got '\{c}' at line \{self.line}, col \{self.col}",
                  )
                None =>
                  Err(
                    "unterminated character literal at line \{start_pos.line}, col \{start_pos.col}",
                  )
              }
          }
        }
      }
    }
    Some(ch) => {
      let _ = self.advance() // 文字を消費
      // 閉じの '\'' を確認
      match self.peek() {
        Some('\'') => {
          let _ = self.advance()
          Ok(Token::CharLit(ch))
        }
        Some(c) =>
          Err(
            "expected closing quote, got '\{c}' at line \{self.line}, col \{self.col}",
          )
        None =>
          Err(
            "unterminated character literal at line \{start_pos.line}, col \{start_pos.col}",
          )
      }
    }
  }
}

/// 文字列リテラルをスキャンする（現在位置が '"' であること前提）
fn Lexer::scan_string_lit(self : Lexer) -> Result[Token, String] {
  let start_pos = self.current_pos()
  let _ = self.advance() // 開始の '"' を消費
  let buf = StringBuilder::new()
  while true {
    match self.peek() {
      None =>
        return Err(
          "unterminated string literal at line \{start_pos.line}, col \{start_pos.col}",
        )
      Some('"') => {
        let _ = self.advance() // 閉じの '"' を消費
        return Ok(Token::StringLit(buf.to_string()))
      }
      Some('\\') => {
        let _ = self.advance() // '\\' を消費
        match self.peek() {
          None =>
            return Err(
              "unterminated escape in string literal at line \{start_pos.line}, col \{start_pos.col}",
            )
          Some(esc_ch) => {
            let _ = self.advance() // エスケープ文字を消費
            match scan_escape(esc_ch) {
              Err(e) =>
                return Err(
                  "\{e} at line \{start_pos.line}, col \{start_pos.col}",
                )
              Ok(ch) => buf.write_char(ch)
            }
          }
        }
      }
      Some(ch) => {
        let _ = self.advance()
        buf.write_char(ch)
      }
    }
  }
  // ここには到達しない
  Err(
    "unterminated string literal at line \{start_pos.line}, col \{start_pos.col}",
  )
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

/// 演算子または区切り記号をスキャンする
fn Lexer::scan_operator_or_punct(self : Lexer) -> Result[Token, String] {
  let pos = self.current_pos()
  let ch = self.advance()
  let next = self.peek()
  match ch {
    Some('+') =>
      match next {
        Some('+') => { let _ = self.advance(); Ok(Token::Inc) }
        _ => Ok(Token::Plus)
      }
    Some('-') =>
      match next {
        Some('-') => { let _ = self.advance(); Ok(Token::Dec) }
        Some('>') => { let _ = self.advance(); Ok(Token::Arrow) }
        _ => Ok(Token::Minus)
      }
    Some('*') => Ok(Token::Star)
    Some('/') => Ok(Token::Slash)
    Some('%') => Ok(Token::Percent)
    Some('=') =>
      match next {
        Some('=') => { let _ = self.advance(); Ok(Token::Eq) }
        _ => Ok(Token::Assign)
      }
    Some('!') =>
      match next {
        Some('=') => { let _ = self.advance(); Ok(Token::Ne) }
        _ => Ok(Token::Bang)
      }
    Some('<') =>
      match next {
        Some('=') => { let _ = self.advance(); Ok(Token::Le) }
        Some('<') => { let _ = self.advance(); Ok(Token::Shl) }
        _ => Ok(Token::Lt)
      }
    Some('>') =>
      match next {
        Some('=') => { let _ = self.advance(); Ok(Token::Ge) }
        Some('>') => { let _ = self.advance(); Ok(Token::Shr) }
        _ => Ok(Token::Gt)
      }
    Some('&') =>
      match next {
        Some('&') => { let _ = self.advance(); Ok(Token::And) }
        _ => Ok(Token::Amp)
      }
    Some('|') =>
      match next {
        Some('|') => { let _ = self.advance(); Ok(Token::Or) }
        _ => Ok(Token::Pipe)
      }
    Some('^') => Ok(Token::Caret)
    Some('~') => Ok(Token::Tilde)
    Some('(') => Ok(Token::LParen)
    Some(')') => Ok(Token::RParen)
    Some('{') => Ok(Token::LBrace)
    Some('}') => Ok(Token::RBrace)
    Some('[') => Ok(Token::LBracket)
    Some(']') => Ok(Token::RBracket)
    Some(';') => Ok(Token::Semi)
    Some(',') => Ok(Token::Comma)
    Some('.') => Ok(Token::Dot)
    Some(c) =>
      Err("unexpected character '\{c}' at line \{pos.line}, col \{pos.col}")
    None =>
      Err("unexpected end of input at line \{pos.line}, col \{pos.col}")
  }
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
      } else if ch == '\'' {
        match self.scan_char_lit() {
          Ok(token) => Ok(LocToken::{ token, pos })
          Err(e) => Err(e)
        }
      } else if ch == '"' {
        match self.scan_string_lit() {
          Ok(token) => Ok(LocToken::{ token, pos })
          Err(e) => Err(e)
        }
      } else if is_alpha(ch) {
        let token = self.scan_ident_or_keyword()
        Ok(LocToken::{ token, pos })
      } else {
        match self.scan_operator_or_punct() {
          Ok(token) => Ok(LocToken::{ token, pos })
          Err(e) => Err(e)
        }
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
