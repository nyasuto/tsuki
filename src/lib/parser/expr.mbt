/// 式のパース: Pratt パーサーで演算子の優先順位を処理する

/// 中置演算子の結合力（binding power）を返す
/// 返り値は (左結合力, 右結合力) のタプル
/// 右結合演算子は右結合力を左結合力より小さくする
fn infix_binding_power(token : @lexer.Token) -> (Int, Int)? {
  match token {
    Assign => Some((2, 1))     // = は右結合
    Or => Some((3, 4))         // ||
    And => Some((5, 6))        // &&
    Pipe => Some((7, 8))       // |
    Caret => Some((9, 10))     // ^
    Amp => Some((11, 12))      // &
    Eq => Some((13, 14))       // ==
    Ne => Some((13, 14))       // !=
    Lt => Some((15, 16))       // <
    Gt => Some((15, 16))       // >
    Le => Some((15, 16))       // <=
    Ge => Some((15, 16))       // >=
    Shl => Some((17, 18))      // <<
    Shr => Some((17, 18))      // >>
    Plus => Some((19, 20))     // +
    Minus => Some((19, 20))    // -
    Star => Some((21, 22))     // *
    Slash => Some((21, 22))    // /
    Percent => Some((21, 22))  // %
    _ => None
  }
}

/// 中置トークンを BinOp に変換する
fn token_to_binop(token : @lexer.Token) -> @ast.BinOp? {
  match token {
    Plus => Some(Add)
    Minus => Some(Sub)
    Star => Some(Mul)
    Slash => Some(Div)
    Percent => Some(Mod)
    Eq => Some(Eq)
    Ne => Some(Ne)
    Lt => Some(Lt)
    Gt => Some(Gt)
    Le => Some(Le)
    Ge => Some(Ge)
    And => Some(LogAnd)
    Or => Some(LogOr)
    Amp => Some(BitAnd)
    Pipe => Some(BitOr)
    Caret => Some(BitXor)
    Shl => Some(Shl)
    Shr => Some(Shr)
    _ => None
  }
}

/// 前置演算子の結合力を返す
fn prefix_binding_power(token : @lexer.Token) -> Int? {
  match token {
    Minus => Some(23)   // -x
    Bang => Some(23)    // !x
    Tilde => Some(23)   // ~x
    Star => Some(23)    // *x (間接参照)
    Amp => Some(23)     // &x (アドレス取得)
    Inc => Some(23)     // ++x (前置インクリメント)
    Dec => Some(23)     // --x (前置デクリメント)
    _ => None
  }
}

/// 前置トークンを UnaryOp に変換する
fn token_to_unaryop(token : @lexer.Token) -> @ast.UnaryOp? {
  match token {
    Minus => Some(Neg)
    Bang => Some(LogNot)
    Tilde => Some(BitNot)
    Star => Some(Deref)
    Amp => Some(AddrOf)
    Inc => Some(PreInc)
    Dec => Some(PreDec)
    _ => None
  }
}

/// 式をパースする（公開エントリポイント）
pub fn Parser::parse_expr(self : Parser) -> Result[@ast.Expr, String] {
  self.parse_expr_bp(0)
}

/// Pratt パーサーのコア: min_bp 以上の結合力を持つ式をパースする
fn Parser::parse_expr_bp(
  self : Parser,
  min_bp : Int
) -> Result[@ast.Expr, String] {
  // 前置部分（一次式または前置単項演算子）のパース
  let mut lhs : @ast.Expr = match self.peek() {
    // 整数リテラル
    IntLit(n) => {
      self.advance() |> ignore
      @ast.Expr::IntLiteral(n)
    }
    // 文字リテラル
    CharLit(c) => {
      self.advance() |> ignore
      @ast.Expr::CharLiteral(c)
    }
    // 文字列リテラル
    StringLit(s) => {
      self.advance() |> ignore
      @ast.Expr::StringLiteral(s)
    }
    // 識別子または関数呼び出し
    Ident(name) => {
      self.advance() |> ignore
      if self.check(@lexer.Token::LParen) {
        match self.parse_call_args(name) {
          Ok(expr) => expr
          Err(e) => return Err(e)
        }
      } else {
        @ast.Expr::Ident(name)
      }
    }
    // 括弧式: (expr)
    LParen => {
      self.advance() |> ignore
      let expr = match self.parse_expr() {
        Ok(e) => e
        Err(e) => return Err(e)
      }
      match self.expect(@lexer.Token::RParen) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      expr
    }
    // 前置単項演算子
    token => {
      match prefix_binding_power(token) {
        Some(rbp) => {
          let op = match token_to_unaryop(token) {
            Some(op) => op
            None => {
              let pos = self.current_pos()
              return Err(
                "unexpected token \{token} at line \{pos.line}, col \{pos.col}",
              )
            }
          }
          self.advance() |> ignore
          let operand = match self.parse_expr_bp(rbp) {
            Ok(e) => e
            Err(e) => return Err(e)
          }
          @ast.Expr::UnaryOp(op, operand)
        }
        None => {
          let pos = self.current_pos()
          return Err(
            "unexpected token \{token} at line \{pos.line}, col \{pos.col}",
          )
        }
      }
    }
  }
  // 中置演算子・後置演算子のループ
  while true {
    let op_token = self.peek()
    // 後置 ++/-- の処理（結合力 25: 前置より高い）
    let postfix_bp = 25
    if op_token == @lexer.Token::Inc && postfix_bp >= min_bp {
      self.advance() |> ignore
      lhs = @ast.Expr::UnaryOp(PostInc, lhs)
      continue
    }
    if op_token == @lexer.Token::Dec && postfix_bp >= min_bp {
      self.advance() |> ignore
      lhs = @ast.Expr::UnaryOp(PostDec, lhs)
      continue
    }
    // メンバアクセス s.field（結合力 25: 後置演算子と同等）
    if op_token == @lexer.Token::Dot && postfix_bp >= min_bp {
      self.advance() |> ignore
      match self.peek() {
        Ident(field_name) => {
          self.advance() |> ignore
          lhs = @ast.Expr::MemberAccess(lhs, field_name)
          continue
        }
        other => {
          let pos = self.current_pos()
          return Err(
            "expected field name after '.', got \{other} at line \{pos.line}, col \{pos.col}",
          )
        }
      }
    }
    // アロー演算 p->field → (*p).field へのデシュガー（結合力 25: 後置演算子と同等）
    if op_token == @lexer.Token::Arrow && postfix_bp >= min_bp {
      self.advance() |> ignore
      match self.peek() {
        Ident(field_name) => {
          self.advance() |> ignore
          lhs = @ast.Expr::MemberAccess(
            @ast.Expr::UnaryOp(Deref, lhs),
            field_name,
          )
          continue
        }
        other => {
          let pos = self.current_pos()
          return Err(
            "expected field name after '->', got \{other} at line \{pos.line}, col \{pos.col}",
          )
        }
      }
    }
    // 配列添字 a[i] → *(a + i) へのデシュガー（結合力 25: 後置演算子と同等）
    if op_token == @lexer.Token::LBracket && postfix_bp >= min_bp {
      self.advance() |> ignore
      let index = match self.parse_expr() {
        Ok(e) => e
        Err(e) => return Err(e)
      }
      match self.expect(@lexer.Token::RBracket) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      lhs = @ast.Expr::UnaryOp(Deref, @ast.Expr::BinaryOp(Add, lhs, index))
      continue
    }
    let should_continue = match infix_binding_power(op_token) {
      None => false
      Some((lbp, _)) => lbp >= min_bp
    }
    if not(should_continue) {
      break
    }
    // ここに来たら中置演算子がある
    match infix_binding_power(op_token) {
      Some((_, rbp)) => {
        self.advance() |> ignore
        let rhs = match self.parse_expr_bp(rbp) {
          Ok(e) => e
          Err(e) => return Err(e)
        }
        // 代入演算子の場合は Assign ノード
        if op_token == @lexer.Token::Assign {
          lhs = @ast.Expr::Assign(lhs, rhs)
        } else {
          match token_to_binop(op_token) {
            Some(binop) => lhs = @ast.Expr::BinaryOp(binop, lhs, rhs)
            None => {
              let pos = self.current_pos()
              return Err(
                "unexpected infix token \{op_token} at line \{pos.line}, col \{pos.col}",
              )
            }
          }
        }
      }
      None => break
    }
  }
  Ok(lhs)
}

/// 関数呼び出しの引数リストをパースする
fn Parser::parse_call_args(
  self : Parser,
  name : String
) -> Result[@ast.Expr, String] {
  match self.expect(@lexer.Token::LParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let args : Array[@ast.Expr] = []
  if not(self.check(@lexer.Token::RParen)) {
    let first_arg = match self.parse_expr() {
      Ok(e) => e
      Err(e) => return Err(e)
    }
    args.push(first_arg)
    while self.check(@lexer.Token::Comma) {
      self.advance() |> ignore
      let arg = match self.parse_expr() {
        Ok(e) => e
        Err(e) => return Err(e)
      }
      args.push(arg)
    }
  }
  match self.expect(@lexer.Token::RParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(@ast.Expr::Call(name, args))
}
