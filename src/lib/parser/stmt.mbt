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

/// 位置情報付き Stmt を作成するヘルパー
fn Parser::make_stmt(self : Parser, kind : @ast.StmtKind, pos : @lexer.Pos) -> @ast.Stmt {
  let _ = self
  { kind, pos }
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
    // for 文
    KwFor => self.parse_for_stmt()
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
  let pos = self.current_pos()
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
  Ok(self.make_stmt(@ast.StmtKind::If(cond, then_stmt, else_stmt), pos))
}

/// while 文のパース: while (expr) stmt
fn Parser::parse_while_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  let pos = self.current_pos()
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
  Ok(self.make_stmt(@ast.StmtKind::While(cond, body), pos))
}

/// for 文のパース: for (init; cond; update) body
fn Parser::parse_for_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  let pos = self.current_pos()
  match self.expect(@lexer.Token::KwFor) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::LParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  // init: 空セミコロン、変数宣言、または式文（いずれもセミコロンを含む）
  let init : @ast.Stmt? = if self.check(@lexer.Token::Semi) {
    self.advance() |> ignore
    None
  } else if is_type_keyword(self.peek()) {
    match self.parse_var_decl() {
      Ok(s) => Some(s)
      Err(e) => return Err(e)
    }
  } else {
    match self.parse_expr_stmt() {
      Ok(s) => Some(s)
      Err(e) => return Err(e)
    }
  }
  // cond: 省略可能（セミコロンだけなら None）
  let cond : @ast.Expr? = if self.check(@lexer.Token::Semi) {
    None
  } else {
    match self.parse_expr() {
      Ok(e) => Some(e)
      Err(e) => return Err(e)
    }
  }
  match self.expect(@lexer.Token::Semi) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  // update: 省略可能（閉じ括弧なら None）
  let update : @ast.Expr? = if self.check(@lexer.Token::RParen) {
    None
  } else {
    match self.parse_expr() {
      Ok(e) => Some(e)
      Err(e) => return Err(e)
    }
  }
  match self.expect(@lexer.Token::RParen) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let body = match self.parse_stmt() {
    Ok(s) => s
    Err(e) => return Err(e)
  }
  Ok(self.make_stmt(@ast.StmtKind::For(init, cond, update, body), pos))
}

/// return 文のパース: return; または return expr;
fn Parser::parse_return_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  let pos = self.current_pos()
  match self.expect(@lexer.Token::KwReturn) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  // セミコロンが来たら return void
  if self.check(@lexer.Token::Semi) {
    self.advance() |> ignore
    return Ok(self.make_stmt(@ast.StmtKind::Return(None), pos))
  }
  let expr = match self.parse_expr() {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::Semi) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(self.make_stmt(@ast.StmtKind::Return(Some(expr)), pos))
}

/// 変数宣言のパース: type name; または type name = expr; または type name[N];
fn Parser::parse_var_decl(self : Parser) -> Result[@ast.Stmt, String] {
  let pos = self.current_pos()
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
      let err_pos = self.current_pos()
      return Err(
        "expected variable name, got \{token} at line \{err_pos.line}, col \{err_pos.col}",
      )
    }
  }
  // 配列宣言のチェック: name[N] または name[]
  let type_name = if self.check(@lexer.Token::LBracket) {
    self.advance() |> ignore
    // サイズ省略（arr[]）かサイズ指定（arr[N]）かを判定
    if self.check(@lexer.Token::RBracket) {
      // arr[] — サイズは初期化リストから推論（後で埋める）
      self.advance() |> ignore
      type_name + "[]"
    } else {
      let size = match self.peek() {
        IntLit(n) => {
          self.advance() |> ignore
          n
        }
        token => {
          let err_pos = self.current_pos()
          return Err(
            "expected array size, got \{token} at line \{err_pos.line}, col \{err_pos.col}",
          )
        }
      }
      match self.expect(@lexer.Token::RBracket) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      type_name + "[" + size.to_string() + "]"
    }
  } else {
    type_name
  }
  // 初期化式があるかチェック（{...} 初期化リストまたは通常の式）
  let init_expr : @ast.Expr? = if self.check(@lexer.Token::Assign) {
    self.advance() |> ignore
    if self.check(@lexer.Token::LBrace) {
      // 初期化リスト: = {expr, expr, ...}
      match self.parse_init_list() {
        Ok(e) => Some(e)
        Err(e) => return Err(e)
      }
    } else {
      match self.parse_expr() {
        Ok(e) => Some(e)
        Err(e) => return Err(e)
      }
    }
  } else {
    None
  }
  // サイズ省略配列 (e.g. "int[]") の場合、初期化リストから要素数を推論
  let type_name = if type_name.has_suffix("[]") {
    match init_expr {
      Some(expr) =>
        match expr.kind {
          InitList(elements) => {
            let base = type_name.substring(end=type_name.length() - 2)
            base + "[" + elements.length().to_string() + "]"
          }
          _ => return Err(
            "array declared with empty brackets must have an initializer list at line \{pos.line}, col \{pos.col}",
          )
        }
      _ => return Err(
        "array declared with empty brackets must have an initializer list at line \{pos.line}, col \{pos.col}",
      )
    }
  } else {
    type_name
  }
  match self.expect(@lexer.Token::Semi) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(self.make_stmt(@ast.StmtKind::VarDecl(type_name, var_name, init_expr), pos))
}

/// 初期化リストのパース: {expr, expr, ...}
fn Parser::parse_init_list(self : Parser) -> Result[@ast.Expr, String] {
  let pos = self.current_pos()
  match self.expect(@lexer.Token::LBrace) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let elements : Array[@ast.Expr] = []
  // 空の初期化リスト {} を許容
  if not(self.check(@lexer.Token::RBrace)) {
    match self.parse_expr() {
      Ok(e) => elements.push(e)
      Err(e) => return Err(e)
    }
    while self.check(@lexer.Token::Comma) {
      self.advance() |> ignore
      // トレーリングカンマ対応: カンマの後に } が来たら終了
      if self.check(@lexer.Token::RBrace) {
        break
      }
      match self.parse_expr() {
        Ok(e) => elements.push(e)
        Err(e) => return Err(e)
      }
    }
  }
  match self.expect(@lexer.Token::RBrace) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(self.make_expr(@ast.ExprKind::InitList(elements), pos))
}

/// 式文のパース: expr;
fn Parser::parse_expr_stmt(self : Parser) -> Result[@ast.Stmt, String] {
  let pos = self.current_pos()
  let expr = match self.parse_expr() {
    Ok(e) => e
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::Semi) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(self.make_stmt(@ast.StmtKind::ExprStmt(expr), pos))
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

/// プログラム全体のパース: トップレベル定義（関数定義・構造体定義）の列
pub fn Parser::parse_program(self : Parser) -> Result[@ast.Program, String] {
  let top_levels : Array[@ast.TopLevel] = []
  while not(self.at_eof()) {
    let top_level = if self.check(@lexer.Token::KwStruct) {
      // struct の後に名前、その後に { なら構造体定義
      // struct Name を型名として使う関数定義の可能性もある
      let saved_pos = self.pos
      self.advance() |> ignore // struct を消費
      match self.peek() {
        Ident(_) => {
          self.advance() |> ignore // 名前を消費
          if self.check(@lexer.Token::LBrace) {
            // struct Name { ... }; → 構造体定義
            self.pos = saved_pos
            self.parse_struct_def()
          } else {
            // struct Name func(...) → 関数定義（戻り値型が struct Name）
            self.pos = saved_pos
            self.parse_func_def()
          }
        }
        _ => {
          self.pos = saved_pos
          self.parse_func_def()
        }
      }
    } else {
      self.parse_func_def()
    }
    match top_level {
      Ok(t) => top_levels.push(t)
      Err(e) => return Err(e)
    }
  }
  Ok(@ast.Program::{ top_levels, })
}

/// 構造体定義のパース: struct Name { type field; ... };
fn Parser::parse_struct_def(self : Parser) -> Result[@ast.TopLevel, String] {
  match self.expect(@lexer.Token::KwStruct) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let struct_name = match self.peek() {
    Ident(name) => {
      self.advance() |> ignore
      name
    }
    token => {
      let pos = self.current_pos()
      return Err(
        "expected struct name, got \{token} at line \{pos.line}, col \{pos.col}",
      )
    }
  }
  match self.expect(@lexer.Token::LBrace) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let fields : Array[@ast.StructField] = []
  while not(self.check(@lexer.Token::RBrace)) && not(self.at_eof()) {
    let field_type = match self.parse_type_name() {
      Ok(t) => t
      Err(e) => return Err(e)
    }
    let field_name = match self.peek() {
      Ident(name) => {
        self.advance() |> ignore
        name
      }
      token => {
        let pos = self.current_pos()
        return Err(
          "expected field name, got \{token} at line \{pos.line}, col \{pos.col}",
        )
      }
    }
    match self.expect(@lexer.Token::Semi) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
    fields.push(@ast.StructField::{ type_name: field_type, name: field_name })
  }
  match self.expect(@lexer.Token::RBrace) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  match self.expect(@lexer.Token::Semi) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  Ok(@ast.TopLevel::StructDef(struct_name, fields))
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
  let pos = self.current_pos()
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
  Ok(self.make_stmt(@ast.StmtKind::Block(stmts), pos))
}
