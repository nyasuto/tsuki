/// 文パーサーのスナップショットテスト

/// ヘルパー: ソースコードから文をパースする
fn parse_stmt_from(source : String) -> Result[@ast.Stmt, String] {
  let lexer = @lexer.Lexer::new(source)
  let tokens = match lexer.tokenize() {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let parser = Parser::new(tokens)
  parser.parse_stmt()
}

/// ヘルパー: ソースコードからブロックをパースする
fn parse_block_from(source : String) -> Result[@ast.Stmt, String] {
  let lexer = @lexer.Lexer::new(source)
  let tokens = match lexer.tokenize() {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let parser = Parser::new(tokens)
  parser.parse_block()
}

// === return 文 ===

test "parse return with integer literal" {
  let result = parse_stmt_from("return 42;")
  inspect!(result, content="Ok(Return(Some(IntLiteral(42))))")
}

test "parse return with expression" {
  let result = parse_stmt_from("return a + b;")
  inspect!(
    result,
    content="Ok(Return(Some(BinaryOp(Add, Ident(\"a\"), Ident(\"b\")))))",
  )
}

test "parse return void" {
  let result = parse_stmt_from("return;")
  inspect!(result, content="Ok(Return(None))")
}

test "parse return with complex expression" {
  let result = parse_stmt_from("return x * 2 + 1;")
  inspect!(
    result,
    content="Ok(Return(Some(BinaryOp(Add, BinaryOp(Mul, Ident(\"x\"), IntLiteral(2)), IntLiteral(1)))))",
  )
}

// === 変数宣言 ===

test "parse var decl without init" {
  let result = parse_stmt_from("int x;")
  inspect!(result, content="Ok(VarDecl(\"int\", \"x\", None))")
}

test "parse var decl with init" {
  let result = parse_stmt_from("int x = 42;")
  inspect!(result, content="Ok(VarDecl(\"int\", \"x\", Some(IntLiteral(42))))")
}

test "parse var decl with expression init" {
  let result = parse_stmt_from("int y = a + b;")
  inspect!(
    result,
    content="Ok(VarDecl(\"int\", \"y\", Some(BinaryOp(Add, Ident(\"a\"), Ident(\"b\")))))",
  )
}

test "parse char var decl" {
  let result = parse_stmt_from("char c = 'A';")
  inspect!(result, content="Ok(VarDecl(\"char\", \"c\", Some(CharLiteral('A'))))")
}

test "parse pointer var decl" {
  let result = parse_stmt_from("int* p;")
  inspect!(result, content="Ok(VarDecl(\"int*\", \"p\", None))")
}

test "parse double pointer var decl" {
  let result = parse_stmt_from("char** pp;")
  inspect!(result, content="Ok(VarDecl(\"char**\", \"pp\", None))")
}

// === 式文 ===

test "parse expr stmt: function call" {
  let result = parse_stmt_from("foo(1, 2);")
  inspect!(
    result,
    content="Ok(ExprStmt(Call(\"foo\", [IntLiteral(1), IntLiteral(2)])))",
  )
}

test "parse expr stmt: assignment" {
  let result = parse_stmt_from("x = 10;")
  inspect!(
    result,
    content="Ok(ExprStmt(Assign(Ident(\"x\"), IntLiteral(10))))",
  )
}

// === ブロック ===

test "parse empty block" {
  let result = parse_block_from("{ }")
  inspect!(result, content="Ok(Block([]))")
}

test "parse block with single return" {
  let result = parse_block_from("{ return 42; }")
  inspect!(result, content="Ok(Block([Return(Some(IntLiteral(42)))]))")
}

test "parse block with multiple statements" {
  let result = parse_block_from("{ int x = 10; int y = 20; return x + y; }")
  inspect!(
    result,
    content="Ok(Block([VarDecl(\"int\", \"x\", Some(IntLiteral(10))), VarDecl(\"int\", \"y\", Some(IntLiteral(20))), Return(Some(BinaryOp(Add, Ident(\"x\"), Ident(\"y\"))))]))",
  )
}

test "parse nested block" {
  let result = parse_block_from("{ { return 1; } }")
  inspect!(
    result,
    content="Ok(Block([Block([Return(Some(IntLiteral(1)))])]))",
  )
}

test "parse block with var decl and assignment" {
  let result = parse_block_from("{ int x; x = 42; return x; }")
  inspect!(
    result,
    content="Ok(Block([VarDecl(\"int\", \"x\", None), ExprStmt(Assign(Ident(\"x\"), IntLiteral(42))), Return(Some(Ident(\"x\")))]))",
  )
}

// === エラーケース ===

test "parse return missing semicolon" {
  let result = parse_stmt_from("return 42")
  inspect!(
    result,
    content="Err(\"expected Semi, got Eof at line 1, col 10\")",
  )
}

test "parse var decl missing semicolon" {
  let result = parse_stmt_from("int x = 1")
  inspect!(
    result,
    content="Err(\"expected Semi, got Eof at line 1, col 10\")",
  )
}

test "parse var decl missing name" {
  let result = parse_stmt_from("int = 1;")
  inspect!(
    result,
    content="Err(\"expected variable name, got Assign at line 1, col 5\")",
  )
}
