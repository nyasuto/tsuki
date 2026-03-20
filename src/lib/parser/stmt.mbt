/// 文（Statement）のパース

/// 型名かどうかを判定する
fn is_type_keyword(token : @lexer.Token) -> Bool {
  match token {
    KwInt => true
    KwChar => true
    KwVoid => true
    KwStruct => true
    _ => false
  }
}

/// 型名トークンを文字列に変換する
fn type_keyword_to_string(token : @lexer.Token) -> String? {
  match token {
    KwInt => Some("int")
    KwChar => Some("char")
    KwVoid => Some("void")
    KwStruct => None // 構造体は別途処理
    _ => None
  }
}

/// 型名をパースする（例: int, char, int*, char**）
fn Parser::parse_type_name(self : Parser) -> Result[String, String] {
  let base = match self.peek() {
    KwStruct => {
      self.advance() |> ignore
      match self.peek() {
        Ident(name) => {
          self.advance() |> ignore
          "struct " + name
        }
        token => {
          let pos = self.current_pos()
          return Err(
            "expected struct name, got \{token} at line \{pos.line}, col \{pos.col}",
          )
        }
      }
    }
    token => {
      match type_keyword_to_string(token) {
        Some(s) => {
          self.advance() |> ignore
          s
        }
        None => {
          let pos = self.current_pos()
          return Err(
            "expected type name, got \{token} at line \{pos.line}, col \{pos.col}",
          )
        }
      }
    }
  }
  // ポインタの * を読み取る
  let mut result = base
  while self.check(@lexer.Token::Star) {
    self.advance() |> ignore
    result = result + "*"
  }
  Ok(result)
}

/// 文をパースする（公開エントリポイント）
pub fn Parser::parse_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  match self.peek() {
    // return 文
    KwReturn => self.parse_return_stmt()
    // ブロック
    LBrace => self.parse_block()
    // 変数宣言（型キーワードで始まる）
    token =>
      if is_type_keyword(token) {
        self.parse_var_decl()
      } else {
        // 式文（代入を含む）
        self.parse_expr_stmt()
      }
  }
}

/// return 文のパース: return; または return expr;
fn Parser::parse_return_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  match self.expect(@lexer.Token::KwReturn) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  // セミコロンが来たら return void
  if self.check(@lexer.Token::Semi) {
    self.advance() |> ignore
    return Ok(@ast.Stmt::Return(None))
  }
  let expr = match self.parse_expr() {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::Semi) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(@ast.Stmt::Return(Some(expr)))
}

/// 変数宣言のパース: type name; または type name = expr;
fn Parser::parse_var_decl(self : Parser) -> Result[@ast.Stmt, String] {
  let type_name = match self.parse_type_name() {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let var_name = match self.peek() {
    Ident(name) => {
      self.advance() |> ignore
      name
    }
    token => {
      let pos = self.current_pos()
      return Err(
        "expected variable name, got \{token} at line \{pos.line}, col \{pos.col}",
      )
    }
  }
  // 初期化式があるかチェック
  let init_expr : @ast.Expr? = if self.check(@lexer.Token::Assign) {
    self.advance() |> ignore
    match self.parse_expr() {
      Ok(e) => Some(e)
      Err(e) => return Err(e)
    }
  } else {
    None
  }
  match self.expect(@lexer.Token::Semi) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(@ast.Stmt::VarDecl(type_name, var_name, init_expr))
}

/// 式文のパース: expr;
fn Parser::parse_expr_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  let expr = match self.parse_expr() {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::Semi) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(@ast.Stmt::ExprStmt(expr))
}

/// ブロックのパース: { stmt* }
pub fn Parser::parse_block(self : Parser) -> Result[@ast.Stmt, String] {
  match self.expect(@lexer.Token::LBrace) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let stmts : Array[@ast.Stmt] = []
  while not(self.check(@lexer.Token::RBrace)) && not(self.at_eof()) {
    let stmt = match self.parse_stmt() {
      Ok(s) => s
      Err(e) => return Err(e)
    }
    stmts.push(stmt)
  }
  match self.expect(@lexer.Token::RBrace) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(@ast.Stmt::Block(stmts))
}
