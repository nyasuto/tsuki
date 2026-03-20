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
    // if 文
    KwIf => self.parse_if_stmt()
    // while 文
    KwWhile => self.parse_while_stmt()
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

/// if 文のパース: if (expr) stmt または if (expr) stmt else stmt
fn Parser::parse_if_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  match self.expect(@lexer.Token::KwIf) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::LParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let cond = match self.parse_expr() {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::RParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let then_stmt = match self.parse_stmt() {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  let else_stmt : @ast.Stmt? = if self.check(@lexer.Token::KwElse) {
    self.advance() |> ignore
    match self.parse_stmt() {
      Ok(s) => Some(s)
      Err(e) => return Err(e)
    }
  } else {
    None
  }
  Ok(@ast.Stmt::If(cond, then_stmt, else_stmt))
}

/// while 文のパース: while (expr) stmt
fn Parser::parse_while_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  match self.expect(@lexer.Token::KwWhile) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::LParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let cond = match self.parse_expr() {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::RParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let body = match self.parse_stmt() {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  Ok(@ast.Stmt::While(cond, body))
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

/// パラメータリストのパース: (type name, type name, ...)
/// 空のパラメータリスト () や (void) にも対応
fn Parser::parse_params(self : Parser) -> Result[Array[@ast.Param], String] {
  match self.expect(@lexer.Token::LParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let params : Array[@ast.Param] = []
  // 空のパラメータリストまたは (void) のケース
  if self.check(@lexer.Token::RParen) {
    self.advance() |> ignore
    return Ok(params)
  }
  if self.check(@lexer.Token::KwVoid) {
    // (void) の場合: 次が ) ならパラメータなし
    let saved_pos = self.pos
    self.advance() |> ignore
    if self.check(@lexer.Token::RParen) {
      self.advance() |> ignore
      return Ok(params)
    }
    // void* などのポインタ型パラメータの可能性があるので位置を戻す
    self.pos = saved_pos
  }
  // 最初のパラメータ
  let first_type = match self.parse_type_name() {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let first_name = match self.peek() {
    Ident(name) => {
      self.advance() |> ignore
      name
    }
    token => {
      let pos = self.current_pos()
      return Err(
        "expected parameter name, got \{token} at line \{pos.line}, col \{pos.col}",
      )
    }
  }
  params.push(@ast.Param::{ type_name: first_type, name: first_name })
  // 残りのパラメータ
  while self.check(@lexer.Token::Comma) {
    self.advance() |> ignore
    let param_type = match self.parse_type_name() {
      Ok(t) => t
      Err(e) => return Err(e)
    }
    let param_name = match self.peek() {
      Ident(name) => {
        self.advance() |> ignore
        name
      }
      token => {
        let pos = self.current_pos()
        return Err(
          "expected parameter name, got \{token} at line \{pos.line}, col \{pos.col}",
        )
      }
    }
    params.push(@ast.Param::{ type_name: param_type, name: param_name })
  }
  match self.expect(@lexer.Token::RParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(params)
}

/// プログラム全体のパース: トップレベル定義（関数定義）の列
pub fn Parser::parse_program(self : Parser) -> Result[@ast.Program, String] {
  let top_levels : Array[@ast.TopLevel] = []
  while not(self.at_eof()) {
    let top_level = match self.parse_func_def() {
      Ok(t) => t
      Err(e) => return Err(e)
    }
    top_levels.push(top_level)
  }
  Ok(@ast.Program::{ top_levels, })
}

/// 関数定義のパース: type name(params) { body }
pub fn Parser::parse_func_def(self : Parser) -> Result[@ast.TopLevel, String] {
  let ret_type = match self.parse_type_name() {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let func_name = match self.peek() {
    Ident(name) => {
      self.advance() |> ignore
      name
    }
    token => {
      let pos = self.current_pos()
      return Err(
        "expected function name, got \{token} at line \{pos.line}, col \{pos.col}",
      )
    }
  }
  let params = match self.parse_params() {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let body = match self.parse_block() {
    Ok(b) => b
    Err(e) => return Err(e)
  }
  Ok(@ast.TopLevel::FuncDef(ret_type, func_name, params, body))
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
