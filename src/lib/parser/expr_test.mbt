// ヘルパー: ソース文字列をトークン化してパーサーを生成する
fn make_parser(src : String) -> @parser.Parser {
  let lexer = @lexer.Lexer::new(src)
  let tokens = match lexer.tokenize() {
    Ok(t) => t
    Err(_) => []
  }
  @parser.Parser::new(tokens)
}

test "parse integer literal" {
  let parser = make_parser("42")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(IntLiteral(42))")
}

test "parse character literal" {
  let parser = make_parser("'a'")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(CharLiteral('a'))")
}

test "parse string literal" {
  let parser = make_parser("\"hello\"")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(StringLiteral(\"hello\"))")
}

test "parse identifier" {
  let parser = make_parser("x")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(Ident(\"x\"))")
}

test "parse simple addition" {
  let parser = make_parser("1 + 2")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(BinaryOp(Add, IntLiteral(1), IntLiteral(2)))")
}

test "parse operator precedence: add and mul" {
  let parser = make_parser("1 + 2 * 3")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Add, IntLiteral(1), BinaryOp(Mul, IntLiteral(2), IntLiteral(3))))",
  )
}

test "parse operator precedence: mul and add" {
  let parser = make_parser("2 * 3 + 4")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Add, BinaryOp(Mul, IntLiteral(2), IntLiteral(3)), IntLiteral(4)))",
  )
}

test "parse left associativity of addition" {
  let parser = make_parser("1 + 2 + 3")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Add, BinaryOp(Add, IntLiteral(1), IntLiteral(2)), IntLiteral(3)))",
  )
}

test "parse parenthesized expression" {
  let parser = make_parser("(1 + 2) * 3")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Mul, BinaryOp(Add, IntLiteral(1), IntLiteral(2)), IntLiteral(3)))",
  )
}

test "parse unary negation" {
  let parser = make_parser("-42")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(UnaryOp(Neg, IntLiteral(42)))")
}

test "parse unary logical not" {
  let parser = make_parser("!x")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(UnaryOp(LogNot, Ident(\"x\")))")
}

test "parse unary bitwise not" {
  let parser = make_parser("~x")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(UnaryOp(BitNot, Ident(\"x\")))")
}

test "parse unary with binary" {
  let parser = make_parser("-1 + 2")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Add, UnaryOp(Neg, IntLiteral(1)), IntLiteral(2)))",
  )
}

test "parse function call with no args" {
  let parser = make_parser("foo()")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(Call(\"foo\", []))")
}

test "parse function call with one arg" {
  let parser = make_parser("foo(42)")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(Call(\"foo\", [IntLiteral(42)]))")
}

test "parse function call with multiple args" {
  let parser = make_parser("add(1, 2)")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(Call(\"add\", [IntLiteral(1), IntLiteral(2)]))")
}

test "parse assignment" {
  let parser = make_parser("x = 42")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(Assign(Ident(\"x\"), IntLiteral(42)))")
}

test "parse assignment right associativity" {
  let parser = make_parser("a = b = 1")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(Assign(Ident(\"a\"), Assign(Ident(\"b\"), IntLiteral(1))))",
  )
}

test "parse comparison operators" {
  let parser = make_parser("a < b")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(BinaryOp(Lt, Ident(\"a\"), Ident(\"b\")))")
}

test "parse equality has lower precedence than comparison" {
  let parser = make_parser("a < b == c > d")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Eq, BinaryOp(Lt, Ident(\"a\"), Ident(\"b\")), BinaryOp(Gt, Ident(\"c\"), Ident(\"d\"))))",
  )
}

test "parse logical and/or precedence" {
  let parser = make_parser("a || b && c")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(LogOr, Ident(\"a\"), BinaryOp(LogAnd, Ident(\"b\"), Ident(\"c\"))))",
  )
}

test "parse complex expression: 3 + 4 * 5" {
  let parser = make_parser("3 + 4 * 5")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Add, IntLiteral(3), BinaryOp(Mul, IntLiteral(4), IntLiteral(5))))",
  )
}

test "parse bitwise operators precedence" {
  let parser = make_parser("a & b | c ^ d")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(BitOr, BinaryOp(BitAnd, Ident(\"a\"), Ident(\"b\")), BinaryOp(BitXor, Ident(\"c\"), Ident(\"d\"))))",
  )
}

test "parse shift operators" {
  let parser = make_parser("a << 2 + 1")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Shl, Ident(\"a\"), BinaryOp(Add, IntLiteral(2), IntLiteral(1))))",
  )
}

test "parse nested function calls" {
  let parser = make_parser("f(g(1), 2 + 3)")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(Call(\"f\", [Call(\"g\", [IntLiteral(1)]), BinaryOp(Add, IntLiteral(2), IntLiteral(3))]))",
  )
}

test "parse deref and addr_of" {
  let parser = make_parser("*p")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(UnaryOp(Deref, Ident(\"p\")))")
  let parser2 = make_parser("&x")
  let expr2 = parser2.parse_expr()
  inspect(expr2, content="Ok(UnaryOp(AddrOf, Ident(\"x\")))")
}

test "parse full precedence chain: arithmetic > comparison > logical" {
  // 1 + 2 < 3 && 4 == 5 || 6
  // 期待: || が最も弱く、&& がその次、== と < が算術より強い
  // ((((1 + 2) < 3) && (4 == 5)) || 6)
  let parser = make_parser("1 + 2 < 3 && 4 == 5 || 6")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(LogOr, BinaryOp(LogAnd, BinaryOp(Lt, BinaryOp(Add, IntLiteral(1), IntLiteral(2)), IntLiteral(3)), BinaryOp(Eq, IntLiteral(4), IntLiteral(5))), IntLiteral(6)))",
  )
}

test "parse precedence: mul > add > shift > comparison > equality > bitand > bitxor > bitor > logand > logor" {
  // a * b + c >> d < e == f & g ^ h | i && j || k
  // 完全な C 優先順位チェイン
  let parser = make_parser("a * b + c >> d < e == f & g ^ h | i && j || k")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(LogOr, BinaryOp(LogAnd, BinaryOp(BitOr, BinaryOp(BitXor, BinaryOp(BitAnd, BinaryOp(Eq, BinaryOp(Lt, BinaryOp(Shr, BinaryOp(Add, BinaryOp(Mul, Ident(\"a\"), Ident(\"b\")), Ident(\"c\")), Ident(\"d\")), Ident(\"e\")), Ident(\"f\")), Ident(\"g\")), Ident(\"h\")), Ident(\"i\")), Ident(\"j\")), Ident(\"k\")))",
  )
}

test "parse modulo and division" {
  let parser = make_parser("10 / 3 % 2")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Mod, BinaryOp(Div, IntLiteral(10), IntLiteral(3)), IntLiteral(2)))",
  )
}

test "parse subtraction left associativity" {
  let parser = make_parser("10 - 3 - 2")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Ok(BinaryOp(Sub, BinaryOp(Sub, IntLiteral(10), IntLiteral(3)), IntLiteral(2)))",
  )
}

test "parse all comparison operators" {
  let parser = make_parser("a <= b")
  let expr = parser.parse_expr()
  inspect(expr, content="Ok(BinaryOp(Le, Ident(\"a\"), Ident(\"b\")))")
  let parser2 = make_parser("a >= b")
  let expr2 = parser2.parse_expr()
  inspect(expr2, content="Ok(BinaryOp(Ge, Ident(\"a\"), Ident(\"b\")))")
  let parser3 = make_parser("a != b")
  let expr3 = parser3.parse_expr()
  inspect(expr3, content="Ok(BinaryOp(Ne, Ident(\"a\"), Ident(\"b\")))")
}

test "parse error on unexpected token" {
  let parser = make_parser(";")
  let expr = parser.parse_expr()
  inspect(
    expr,
    content="Err(\"unexpected token Semi at line 1, col 1\")",
  )
}
