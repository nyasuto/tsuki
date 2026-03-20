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

// === if / else 文 ===

test "parse if without else" {
  let result = parse_stmt_from("if (x > 0) return x;")
  inspect!(
    result,
    content="Ok(If(BinaryOp(Gt, Ident(\"x\"), IntLiteral(0)), Return(Some(Ident(\"x\"))), None))",
  )
}

test "parse if with else" {
  let result = parse_stmt_from("if (x < 0) return 0; else return 1;")
  inspect!(
    result,
    content="Ok(If(BinaryOp(Lt, Ident(\"x\"), IntLiteral(0)), Return(Some(IntLiteral(0))), Some(Return(Some(IntLiteral(1))))))",
  )
}

test "parse if with block" {
  let result = parse_stmt_from("if (a == b) { return 1; }")
  inspect!(
    result,
    content="Ok(If(BinaryOp(Eq, Ident(\"a\"), Ident(\"b\")), Block([Return(Some(IntLiteral(1)))]), None))",
  )
}

test "parse if/else with blocks" {
  let result = parse_stmt_from("if (x) { return 1; } else { return 0; }")
  inspect!(
    result,
    content="Ok(If(Ident(\"x\"), Block([Return(Some(IntLiteral(1)))]), Some(Block([Return(Some(IntLiteral(0)))]))))",
  )
}

test "parse nested if/else (dangling else)" {
  let result = parse_stmt_from("if (a) if (b) return 1; else return 2;")
  inspect!(
    result,
    content="Ok(If(Ident(\"a\"), If(Ident(\"b\"), Return(Some(IntLiteral(1))), Some(Return(Some(IntLiteral(2))))), None))",
  )
}

test "parse if/else if/else chain" {
  let result = parse_stmt_from(
    "if (x == 1) return 10; else if (x == 2) return 20; else return 30;",
  )
  inspect!(
    result,
    content="Ok(If(BinaryOp(Eq, Ident(\"x\"), IntLiteral(1)), Return(Some(IntLiteral(10))), Some(If(BinaryOp(Eq, Ident(\"x\"), IntLiteral(2)), Return(Some(IntLiteral(20))), Some(Return(Some(IntLiteral(30))))))))",
  )
}

test "parse if missing lparen" {
  let result = parse_stmt_from("if x > 0) return x;")
  inspect!(
    result,
    content="Err(\"expected LParen, got Ident(\\\"x\\\") at line 1, col 4\")",
  )
}

// === while 文 ===

test "parse while with block body" {
  let result = parse_stmt_from("while (x > 0) { x = x - 1; }")
  inspect!(
    result,
    content="Ok(While(BinaryOp(Gt, Ident(\"x\"), IntLiteral(0)), Block([ExprStmt(Assign(Ident(\"x\"), BinaryOp(Sub, Ident(\"x\"), IntLiteral(1))))])))",
  )
}

test "parse while with single statement body" {
  let result = parse_stmt_from("while (i < 10) i = i + 1;")
  inspect!(
    result,
    content="Ok(While(BinaryOp(Lt, Ident(\"i\"), IntLiteral(10)), ExprStmt(Assign(Ident(\"i\"), BinaryOp(Add, Ident(\"i\"), IntLiteral(1))))))",
  )
}

test "parse while with return body" {
  let result = parse_stmt_from("while (1) return 0;")
  inspect!(
    result,
    content="Ok(While(IntLiteral(1), Return(Some(IntLiteral(0)))))",
  )
}

test "parse nested while" {
  let result = parse_stmt_from("while (a) while (b) return 1;")
  inspect!(
    result,
    content="Ok(While(Ident(\"a\"), While(Ident(\"b\"), Return(Some(IntLiteral(1))))))",
  )
}

test "parse while missing lparen" {
  let result = parse_stmt_from("while x > 0) { }")
  inspect!(
    result,
    content="Err(\"expected LParen, got Ident(\\\"x\\\") at line 1, col 7\")",
  )
}

// === for 文 ===

test "parse for with all three clauses" {
  let result = parse_stmt_from("for (int i = 0; i < 10; i = i + 1) { x = x + i; }")
  inspect!(
    result,
    content="Ok(For(Some(VarDecl(\"int\", \"i\", Some(IntLiteral(0)))), Some(BinaryOp(Lt, Ident(\"i\"), IntLiteral(10))), Some(Assign(Ident(\"i\"), BinaryOp(Add, Ident(\"i\"), IntLiteral(1)))), Block([ExprStmt(Assign(Ident(\"x\"), BinaryOp(Add, Ident(\"x\"), Ident(\"i\"))))])))",
  )
}

test "parse for with empty init" {
  let result = parse_stmt_from("for (; i < 10; i = i + 1) return i;")
  inspect!(
    result,
    content="Ok(For(None, Some(BinaryOp(Lt, Ident(\"i\"), IntLiteral(10))), Some(Assign(Ident(\"i\"), BinaryOp(Add, Ident(\"i\"), IntLiteral(1)))), Return(Some(Ident(\"i\")))))",
  )
}

test "parse for with empty cond" {
  let result = parse_stmt_from("for (int i = 0; ; i = i + 1) return i;")
  inspect!(
    result,
    content="Ok(For(Some(VarDecl(\"int\", \"i\", Some(IntLiteral(0)))), None, Some(Assign(Ident(\"i\"), BinaryOp(Add, Ident(\"i\"), IntLiteral(1)))), Return(Some(Ident(\"i\")))))",
  )
}

test "parse for with empty update" {
  let result = parse_stmt_from("for (int i = 0; i < 10;) return i;")
  inspect!(
    result,
    content="Ok(For(Some(VarDecl(\"int\", \"i\", Some(IntLiteral(0)))), Some(BinaryOp(Lt, Ident(\"i\"), IntLiteral(10))), None, Return(Some(Ident(\"i\")))))",
  )
}

test "parse for with all empty clauses (infinite loop)" {
  let result = parse_stmt_from("for (;;) return 0;")
  inspect!(
    result,
    content="Ok(For(None, None, None, Return(Some(IntLiteral(0)))))",
  )
}

test "parse for with expr init" {
  let result = parse_stmt_from("for (i = 0; i < 5; i = i + 1) return i;")
  inspect!(
    result,
    content="Ok(For(Some(ExprStmt(Assign(Ident(\"i\"), IntLiteral(0)))), Some(BinaryOp(Lt, Ident(\"i\"), IntLiteral(5))), Some(Assign(Ident(\"i\"), BinaryOp(Add, Ident(\"i\"), IntLiteral(1)))), Return(Some(Ident(\"i\")))))",
  )
}

test "parse for missing lparen" {
  let result = parse_stmt_from("for int i = 0; i < 10; i = i + 1) { }")
  inspect!(
    result,
    content="Err(\"expected LParen, got KwInt at line 1, col 5\")",
  )
}

// === 関数定義 ===

/// ヘルパー: ソースコードから関数定義をパースする
fn parse_func_def_from(source : String) -> Result[@ast.TopLevel, String] {
  let lexer = @lexer.Lexer::new(source)
  let tokens = match lexer.tokenize() {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let parser = Parser::new(tokens)
  parser.parse_func_def()
}

test "parse simple function: int main() { return 42; }" {
  let result = parse_func_def_from("int main() { return 42; }")
  inspect!(
    result,
    content="Ok(FuncDef(\"int\", \"main\", [], Block([Return(Some(IntLiteral(42)))])))",
  )
}

test "parse function with params: int add(int a, int b)" {
  let result = parse_func_def_from("int add(int a, int b) { return a + b; }")
  inspect!(
    result,
    content="Ok(FuncDef(\"int\", \"add\", [{type_name: \"int\", name: \"a\"}, {type_name: \"int\", name: \"b\"}], Block([Return(Some(BinaryOp(Add, Ident(\"a\"), Ident(\"b\"))))])))",
  )
}

test "parse void function with no params" {
  let result = parse_func_def_from("void noop() { }")
  inspect!(
    result,
    content="Ok(FuncDef(\"void\", \"noop\", [], Block([])))",
  )
}

test "parse function with void param" {
  let result = parse_func_def_from("int main(void) { return 0; }")
  inspect!(
    result,
    content="Ok(FuncDef(\"int\", \"main\", [], Block([Return(Some(IntLiteral(0)))])))",
  )
}

test "parse function with pointer param" {
  let result = parse_func_def_from("int deref(int* p) { return *p; }")
  inspect!(
    result,
    content="Ok(FuncDef(\"int\", \"deref\", [{type_name: \"int*\", name: \"p\"}], Block([Return(Some(UnaryOp(Deref, Ident(\"p\"))))])))",
  )
}

test "parse function with multiple params and body" {
  let result = parse_func_def_from(
    "int calc(int x, int y, int z) { int r = x + y; return r * z; }",
  )
  inspect!(
    result,
    content="Ok(FuncDef(\"int\", \"calc\", [{type_name: \"int\", name: \"x\"}, {type_name: \"int\", name: \"y\"}, {type_name: \"int\", name: \"z\"}], Block([VarDecl(\"int\", \"r\", Some(BinaryOp(Add, Ident(\"x\"), Ident(\"y\")))), Return(Some(BinaryOp(Mul, Ident(\"r\"), Ident(\"z\"))))])))",
  )
}

test "parse function returning pointer" {
  let result = parse_func_def_from("int* getptr() { return p; }")
  inspect!(
    result,
    content="Ok(FuncDef(\"int*\", \"getptr\", [], Block([Return(Some(Ident(\"p\")))])))",
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

/// ヘルパー: ソースコードからプログラムをパースする
fn parse_program_from(source : String) -> Result[@ast.Program, String] {
  let lexer = @lexer.Lexer::new(source)
  let tokens = match lexer.tokenize() {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let parser = Parser::new(tokens)
  parser.parse_program()
}

test "parse program: single function" {
  let result = parse_program_from("int main() { return 42; }")
  inspect!(result, content=(
    #|Ok({top_levels: [FuncDef("int", "main", [], Block([Return(Some(IntLiteral(42)))]))]})
  ))
}

test "parse program: multiple functions" {
  let result = parse_program_from(
    "int add(int a, int b) { return a + b; } int main() { return add(3, 4); }",
  )
  inspect!(result, content=(
    #|Ok({top_levels: [FuncDef("int", "add", [{type_name: "int", name: "a"}, {type_name: "int", name: "b"}], Block([Return(Some(BinaryOp(Add, Ident("a"), Ident("b"))))])), FuncDef("int", "main", [], Block([Return(Some(Call("add", [IntLiteral(3), IntLiteral(4)])))]))]})
  ))
}

test "parse program: empty program" {
  let result = parse_program_from("")
  inspect!(result, content=(
    #|Ok({top_levels: []})
  ))
}

test "parse program: struct definition" {
  let result = parse_program_from(
    "struct Point { int x; int y; }; int main() { return 0; }",
  )
  inspect!(result, content=(
    #|Ok({top_levels: [StructDef("Point", [{type_name: "int", name: "x"}, {type_name: "int", name: "y"}]), FuncDef("int", "main", [], Block([Return(Some(IntLiteral(0)))]))]})
  ))
}

test "parse program: struct with pointer field" {
  let result = parse_program_from(
    "struct Node { int value; int* next; }; int main() { return 0; }",
  )
  inspect!(result, content=(
    #|Ok({top_levels: [StructDef("Node", [{type_name: "int", name: "value"}, {type_name: "int*", name: "next"}]), FuncDef("int", "main", [], Block([Return(Some(IntLiteral(0)))]))]})
  ))
}

test "parse program: struct return type function" {
  // struct Point* get_point() { ... } のような関数は構造体定義ではない
  let result = parse_program_from(
    "struct Point { int x; }; struct Point* get() { return 0; } int main() { return 0; }",
  )
  inspect!(result.is_ok(), content="true")
}

// === 配列宣言 ===

test "parse array declaration" {
  let result = parse_stmt_from("int arr[10];")
  inspect!(result, content="Ok(VarDecl(\"int[10]\", \"arr\", None))")
}

test "parse char array declaration" {
  let result = parse_stmt_from("char buf[256];")
  inspect!(result, content="Ok(VarDecl(\"char[256]\", \"buf\", None))")
}

test "parse pointer array declaration" {
  let result = parse_stmt_from("int* ptrs[5];")
  inspect!(result, content="Ok(VarDecl(\"int*[5]\", \"ptrs\", None))")
}

// === 配列初期化リスト ===

test "parse array init list" {
  let result = parse_stmt_from("int arr[] = {1, 2, 3};")
  inspect!(
    result,
    content="Ok(VarDecl(\"int[3]\", \"arr\", Some(InitList([IntLiteral(1), IntLiteral(2), IntLiteral(3)]))))",
  )
}

test "parse array init list with explicit size" {
  let result = parse_stmt_from("int arr[5] = {10, 20, 30};")
  inspect!(
    result,
    content="Ok(VarDecl(\"int[5]\", \"arr\", Some(InitList([IntLiteral(10), IntLiteral(20), IntLiteral(30)]))))",
  )
}

test "parse array init list single element" {
  let result = parse_stmt_from("int arr[] = {42};")
  inspect!(
    result,
    content="Ok(VarDecl(\"int[1]\", \"arr\", Some(InitList([IntLiteral(42)]))))",
  )
}

test "parse array empty brackets without init is error" {
  let result = parse_stmt_from("int arr[];")
  inspect!(
    result,
    content="Err(\"array declared with empty brackets must have an initializer list at line 1, col 1\")",
  )
}
