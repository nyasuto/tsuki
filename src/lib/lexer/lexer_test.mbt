test "Lexer::new initializes correctly" {
  let lexer = @lexer.Lexer::new("hello")
  inspect(lexer.pos, content="0")
  inspect(lexer.line, content="1")
  inspect(lexer.col, content="1")
}

test "Lexer::peek returns current char without advancing" {
  let lexer = @lexer.Lexer::new("abc")
  inspect(lexer.peek(), content="Some('a')")
  // peek should not change position
  inspect(lexer.peek(), content="Some('a')")
  inspect(lexer.pos, content="0")
}

test "Lexer::peek on empty input returns None" {
  let lexer = @lexer.Lexer::new("")
  inspect(lexer.peek(), content="None")
}

test "Lexer::peek_ahead returns nth char" {
  let lexer = @lexer.Lexer::new("abcdef")
  inspect(lexer.peek_ahead(0), content="Some('a')")
  inspect(lexer.peek_ahead(2), content="Some('c')")
  inspect(lexer.peek_ahead(5), content="Some('f')")
  inspect(lexer.peek_ahead(6), content="None")
}

test "Lexer::advance consumes char and updates position" {
  let lexer = @lexer.Lexer::new("ab")
  inspect(lexer.advance(), content="Some('a')")
  inspect(lexer.pos, content="1")
  inspect(lexer.col, content="2")
  inspect(lexer.advance(), content="Some('b')")
  inspect(lexer.pos, content="2")
  inspect(lexer.col, content="3")
  inspect(lexer.advance(), content="None")
}

test "Lexer::advance tracks line and column on newline" {
  let lexer = @lexer.Lexer::new("a\nb")
  inspect(lexer.advance(), content="Some('a')")
  inspect(lexer.line, content="1")
  inspect(lexer.col, content="2")
  // advance over newline
  inspect(lexer.advance(), content=
    (#|Some('\n')
)
  )
  inspect(lexer.line, content="2")
  inspect(lexer.col, content="1")
  // next char on new line
  inspect(lexer.advance(), content="Some('b')")
  inspect(lexer.line, content="2")
  inspect(lexer.col, content="2")
}

test "Lexer::current_pos returns current position" {
  let lexer = @lexer.Lexer::new("x\ny")
  inspect(lexer.current_pos(), content="{line: 1, col: 1}")
  let _ = lexer.advance() // 'x'
  inspect(lexer.current_pos(), content="{line: 1, col: 2}")
  let _ = lexer.advance() // '\n'
  inspect(lexer.current_pos(), content="{line: 2, col: 1}")
}

test "Lexer::is_eof" {
  let lexer = @lexer.Lexer::new("a")
  inspect(lexer.is_eof(), content="false")
  let _ = lexer.advance()
  inspect(lexer.is_eof(), content="true")
}

test "scan integer literal: single digit" {
  let lexer = @lexer.Lexer::new("0")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(0), pos: {line: 1, col: 1}})")
}

test "scan integer literal: multi digit" {
  let lexer = @lexer.Lexer::new("42")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(42), pos: {line: 1, col: 1}})")
}

test "scan integer literal: large number" {
  let lexer = @lexer.Lexer::new("12345")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(12345), pos: {line: 1, col: 1}})")
}

test "scan integer literal: stops at non-digit" {
  let lexer = @lexer.Lexer::new("123abc")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(123), pos: {line: 1, col: 1}})")
  // position should be at 'a'
  inspect(lexer.pos, content="3")
}

test "next_token returns Eof on empty input" {
  let lexer = @lexer.Lexer::new("")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: Eof, pos: {line: 1, col: 1}})")
}

test "next_token returns error on unexpected char" {
  let lexer = @lexer.Lexer::new("@")
  let result = lexer.next_token()
  inspect(result, content="Err(\"unexpected character '@' at line 1, col 1\")")
}

test "tokenize: sequence of integer literals separated by non-digits" {
  let lexer = @lexer.Lexer::new("42")
  let result = lexer.tokenize()
  inspect(
    result,
    content="Ok([{token: IntLit(42), pos: {line: 1, col: 1}}, {token: Eof, pos: {line: 1, col: 3}}])",
  )
}

// --- 文字リテラルのテスト ---

test "scan char literal: simple character" {
  let lexer = @lexer.Lexer::new("'a'")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: CharLit('a'), pos: {line: 1, col: 1}})")
}

test "scan char literal: digit character" {
  let lexer = @lexer.Lexer::new("'0'")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: CharLit('0'), pos: {line: 1, col: 1}})")
}

test "scan char literal: escape newline" {
  let lexer = @lexer.Lexer::new("'\\n'")
  let result = lexer.next_token()
  let expected =
    #|Ok({token: CharLit('\n'), pos: {line: 1, col: 1}})
  inspect(result, content=expected)
}

test "scan char literal: escape tab" {
  let lexer = @lexer.Lexer::new("'\\t'")
  let result = lexer.next_token()
  let expected =
    #|Ok({token: CharLit('\t'), pos: {line: 1, col: 1}})
  inspect(result, content=expected)
}

test "scan char literal: escape backslash" {
  let lexer = @lexer.Lexer::new("'\\\\'")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: CharLit('\\\\'), pos: {line: 1, col: 1}})")
}

test "scan char literal: escape null" {
  let lexer = @lexer.Lexer::new("'\\0'")
  let result = lexer.next_token()
  let expected =
    #|Ok({token: CharLit('\u{00}'), pos: {line: 1, col: 1}})
  inspect(result, content=expected)
}

test "scan char literal: empty literal error" {
  let lexer = @lexer.Lexer::new("''")
  let result = lexer.next_token()
  inspect(result, content="Err(\"empty character literal at line 1, col 1\")")
}

test "scan char literal: unterminated error" {
  let lexer = @lexer.Lexer::new("'a")
  let result = lexer.next_token()
  inspect(
    result,
    content="Err(\"unterminated character literal at line 1, col 1\")",
  )
}

// --- 文字列リテラルのテスト ---

test "scan string literal: simple string" {
  let lexer = @lexer.Lexer::new("\"hello\"")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: StringLit(\"hello\"), pos: {line: 1, col: 1}})",
  )
}

test "scan string literal: empty string" {
  let lexer = @lexer.Lexer::new("\"\"")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: StringLit(\"\"), pos: {line: 1, col: 1}})",
  )
}

test "scan string literal: with escape sequences" {
  let lexer = @lexer.Lexer::new("\"hello\\nworld\"")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: StringLit(\"hello\\nworld\"), pos: {line: 1, col: 1}})",
  )
}

test "scan string literal: multiple escapes" {
  let lexer = @lexer.Lexer::new("\"a\\tb\\\\c\"")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: StringLit(\"a\\tb\\\\c\"), pos: {line: 1, col: 1}})",
  )
}

test "scan string literal: escape null in string" {
  let lexer = @lexer.Lexer::new("\"a\\0b\"")
  let result = lexer.next_token()
  let expected =
    #|Ok({token: StringLit("a\u{00}b"), pos: {line: 1, col: 1}})
  inspect(result, content=expected)
}

test "scan string literal: unterminated error" {
  let lexer = @lexer.Lexer::new("\"hello")
  let result = lexer.next_token()
  inspect(
    result,
    content="Err(\"unterminated string literal at line 1, col 1\")",
  )
}

test "scan string literal: unknown escape error" {
  let lexer = @lexer.Lexer::new("\"\\q\"")
  let result = lexer.next_token()
  inspect(
    result,
    content="Err(\"unknown escape sequence '\\\\q' at line 1, col 1\")",
  )
}

test "scan char literal: unknown escape error" {
  let lexer = @lexer.Lexer::new("'\\q'")
  let result = lexer.next_token()
  inspect(
    result,
    content="Err(\"unknown escape sequence '\\\\q' at line 1, col 1\")",
  )
}

// --- 識別子とキーワードのテスト ---

test "scan identifier: simple name" {
  let lexer = @lexer.Lexer::new("foo")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: Ident(\"foo\"), pos: {line: 1, col: 1}})")
}

test "scan identifier: with underscore prefix" {
  let lexer = @lexer.Lexer::new("_bar")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: Ident(\"_bar\"), pos: {line: 1, col: 1}})",
  )
}

test "scan identifier: with digits" {
  let lexer = @lexer.Lexer::new("x42")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: Ident(\"x42\"), pos: {line: 1, col: 1}})",
  )
}

test "scan identifier: underscore only" {
  let lexer = @lexer.Lexer::new("_")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: Ident(\"_\"), pos: {line: 1, col: 1}})")
}

test "scan identifier: mixed case" {
  let lexer = @lexer.Lexer::new("myVar_2")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: Ident(\"myVar_2\"), pos: {line: 1, col: 1}})",
  )
}

test "scan keyword: int" {
  let lexer = @lexer.Lexer::new("int")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwInt, pos: {line: 1, col: 1}})")
}

test "scan keyword: char" {
  let lexer = @lexer.Lexer::new("char")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwChar, pos: {line: 1, col: 1}})")
}

test "scan keyword: void" {
  let lexer = @lexer.Lexer::new("void")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwVoid, pos: {line: 1, col: 1}})")
}

test "scan keyword: struct" {
  let lexer = @lexer.Lexer::new("struct")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwStruct, pos: {line: 1, col: 1}})")
}

test "scan keyword: if" {
  let lexer = @lexer.Lexer::new("if")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwIf, pos: {line: 1, col: 1}})")
}

test "scan keyword: else" {
  let lexer = @lexer.Lexer::new("else")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwElse, pos: {line: 1, col: 1}})")
}

test "scan keyword: while" {
  let lexer = @lexer.Lexer::new("while")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwWhile, pos: {line: 1, col: 1}})")
}

test "scan keyword: for" {
  let lexer = @lexer.Lexer::new("for")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwFor, pos: {line: 1, col: 1}})")
}

test "scan keyword: return" {
  let lexer = @lexer.Lexer::new("return")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwReturn, pos: {line: 1, col: 1}})")
}

test "scan keyword: sizeof" {
  let lexer = @lexer.Lexer::new("sizeof")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwSizeof, pos: {line: 1, col: 1}})")
}

test "scan identifier: keyword prefix is not keyword" {
  let lexer = @lexer.Lexer::new("integer")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: Ident(\"integer\"), pos: {line: 1, col: 1}})",
  )
}

test "scan identifier: keyword suffix is not keyword" {
  let lexer = @lexer.Lexer::new("returnValue")
  let result = lexer.next_token()
  inspect(
    result,
    content="Ok({token: Ident(\"returnValue\"), pos: {line: 1, col: 1}})",
  )
}

test "scan identifier: stops at non-alnum" {
  let lexer = @lexer.Lexer::new("foo+bar")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: Ident(\"foo\"), pos: {line: 1, col: 1}})")
  inspect(lexer.pos, content="3")
}

// --- 演算子と区切り記号のテスト ---

test "scan single-char operators" {
  let lexer = @lexer.Lexer::new("+-*/%^~")
  inspect(lexer.next_token(), content="Ok({token: Plus, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Minus, pos: {line: 1, col: 2}})")
  inspect(lexer.next_token(), content="Ok({token: Star, pos: {line: 1, col: 3}})")
  inspect(lexer.next_token(), content="Ok({token: Slash, pos: {line: 1, col: 4}})")
  inspect(lexer.next_token(), content="Ok({token: Percent, pos: {line: 1, col: 5}})")
  inspect(lexer.next_token(), content="Ok({token: Caret, pos: {line: 1, col: 6}})")
  inspect(lexer.next_token(), content="Ok({token: Tilde, pos: {line: 1, col: 7}})")
}

test "scan two-char operators: == != <= >= && || << >> ++ -- ->" {
  let lexer = @lexer.Lexer::new("==!=<=>=&&||<<>>++--->")
  inspect(lexer.next_token(), content="Ok({token: Eq, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Ne, pos: {line: 1, col: 3}})")
  inspect(lexer.next_token(), content="Ok({token: Le, pos: {line: 1, col: 5}})")
  inspect(lexer.next_token(), content="Ok({token: Ge, pos: {line: 1, col: 7}})")
  inspect(lexer.next_token(), content="Ok({token: And, pos: {line: 1, col: 9}})")
  inspect(lexer.next_token(), content="Ok({token: Or, pos: {line: 1, col: 11}})")
  inspect(lexer.next_token(), content="Ok({token: Shl, pos: {line: 1, col: 13}})")
  inspect(lexer.next_token(), content="Ok({token: Shr, pos: {line: 1, col: 15}})")
  inspect(lexer.next_token(), content="Ok({token: Inc, pos: {line: 1, col: 17}})")
  inspect(lexer.next_token(), content="Ok({token: Dec, pos: {line: 1, col: 19}})")
  inspect(lexer.next_token(), content="Ok({token: Arrow, pos: {line: 1, col: 21}})")
}

test "scan single vs double char disambiguation: = vs ==" {
  let lexer = @lexer.Lexer::new("=== ")
  inspect(lexer.next_token(), content="Ok({token: Eq, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Assign, pos: {line: 1, col: 3}})")
}

test "scan single vs double char disambiguation: & vs &&" {
  let lexer = @lexer.Lexer::new("&&&")
  inspect(lexer.next_token(), content="Ok({token: And, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Amp, pos: {line: 1, col: 3}})")
}

test "scan single vs double char disambiguation: ! vs !=" {
  let lexer = @lexer.Lexer::new("!!=")
  inspect(lexer.next_token(), content="Ok({token: Bang, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Ne, pos: {line: 1, col: 2}})")
}

test "scan single vs double char disambiguation: < vs << vs <=" {
  let lexer = @lexer.Lexer::new("<<<=<")
  inspect(lexer.next_token(), content="Ok({token: Shl, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Le, pos: {line: 1, col: 3}})")
  inspect(lexer.next_token(), content="Ok({token: Lt, pos: {line: 1, col: 5}})")
}

test "scan delimiters" {
  let lexer = @lexer.Lexer::new("(){}[];,.")
  inspect(lexer.next_token(), content="Ok({token: LParen, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: RParen, pos: {line: 1, col: 2}})")
  inspect(lexer.next_token(), content="Ok({token: LBrace, pos: {line: 1, col: 3}})")
  inspect(lexer.next_token(), content="Ok({token: RBrace, pos: {line: 1, col: 4}})")
  inspect(lexer.next_token(), content="Ok({token: LBracket, pos: {line: 1, col: 5}})")
  inspect(lexer.next_token(), content="Ok({token: RBracket, pos: {line: 1, col: 6}})")
  inspect(lexer.next_token(), content="Ok({token: Semi, pos: {line: 1, col: 7}})")
  inspect(lexer.next_token(), content="Ok({token: Comma, pos: {line: 1, col: 8}})")
  inspect(lexer.next_token(), content="Ok({token: Dot, pos: {line: 1, col: 9}})")
}

test "scan pipe single vs double: | vs ||" {
  let lexer = @lexer.Lexer::new("|||")
  inspect(lexer.next_token(), content="Ok({token: Or, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Pipe, pos: {line: 1, col: 3}})")
}

test "scan > vs >> vs >=" {
  let lexer = @lexer.Lexer::new(">>>=>" )
  inspect(lexer.next_token(), content="Ok({token: Shr, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Ge, pos: {line: 1, col: 3}})")
  inspect(lexer.next_token(), content="Ok({token: Gt, pos: {line: 1, col: 5}})")
}

test "scan minus variants: - vs -- vs ->" {
  let lexer = @lexer.Lexer::new("--->=->-")
  inspect(lexer.next_token(), content="Ok({token: Dec, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Arrow, pos: {line: 1, col: 3}})")
  inspect(lexer.next_token(), content="Ok({token: Assign, pos: {line: 1, col: 5}})")
  inspect(lexer.next_token(), content="Ok({token: Arrow, pos: {line: 1, col: 6}})")
  inspect(lexer.next_token(), content="Ok({token: Minus, pos: {line: 1, col: 8}})")
}

// --- ホワイトスペースとコメントのテスト ---

test "skip whitespace: spaces and tabs" {
  let lexer = @lexer.Lexer::new("   42")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(42), pos: {line: 1, col: 4}})")
}

test "skip whitespace: newlines update line number" {
  let lexer = @lexer.Lexer::new("\n\n42")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(42), pos: {line: 3, col: 1}})")
}

test "skip whitespace: mixed whitespace" {
  let lexer = @lexer.Lexer::new("  \t\n  foo")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: Ident(\"foo\"), pos: {line: 2, col: 3}})")
}

test "skip whitespace: only whitespace gives Eof" {
  let lexer = @lexer.Lexer::new("   \n\t  ")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: Eof, pos: {line: 2, col: 4}})")
}

test "skip line comment: basic" {
  let lexer = @lexer.Lexer::new("// comment\n42")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(42), pos: {line: 2, col: 1}})")
}

test "skip line comment: at end of file" {
  let lexer = @lexer.Lexer::new("// comment")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: Eof, pos: {line: 1, col: 11}})")
}

test "skip line comment: preserves following token" {
  let lexer = @lexer.Lexer::new("int // type\nfoo")
  inspect(lexer.next_token(), content="Ok({token: KwInt, pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Ident(\"foo\"), pos: {line: 2, col: 1}})")
}

test "skip block comment: basic" {
  let lexer = @lexer.Lexer::new("/* comment */42")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(42), pos: {line: 1, col: 14}})")
}

test "skip block comment: multiline" {
  let lexer = @lexer.Lexer::new("/* line1\nline2 */foo")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: Ident(\"foo\"), pos: {line: 2, col: 9}})")
}

test "skip block comment: unterminated error" {
  let lexer = @lexer.Lexer::new("/* unterminated")
  let result = lexer.next_token()
  inspect(
    result,
    content="Err(\"unterminated block comment at line 1, col 1\")",
  )
}

test "skip block comment: with stars inside" {
  let lexer = @lexer.Lexer::new("/*** comment ***/42")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: IntLit(42), pos: {line: 1, col: 18}})")
}

test "skip mixed whitespace and comments" {
  let lexer = @lexer.Lexer::new("  // first\n  /* second */ return")
  let result = lexer.next_token()
  inspect(result, content="Ok({token: KwReturn, pos: {line: 2, col: 16}})")
}

test "slash token not confused with comment" {
  let lexer = @lexer.Lexer::new("a / b")
  inspect(lexer.next_token(), content="Ok({token: Ident(\"a\"), pos: {line: 1, col: 1}})")
  inspect(lexer.next_token(), content="Ok({token: Slash, pos: {line: 1, col: 3}})")
  inspect(lexer.next_token(), content="Ok({token: Ident(\"b\"), pos: {line: 1, col: 5}})")
}

test "tokenize with whitespace: int main" {
  let lexer = @lexer.Lexer::new("int main")
  let result = lexer.tokenize()
  inspect(
    result,
    content="Ok([{token: KwInt, pos: {line: 1, col: 1}}, {token: Ident(\"main\"), pos: {line: 1, col: 5}}, {token: Eof, pos: {line: 1, col: 9}}])",
  )
}

test "snapshot: int main() { return 42; }" {
  let lexer = @lexer.Lexer::new("int main() { return 42; }")
  let result = lexer.tokenize()
  inspect(
    result,
    content="Ok([{token: KwInt, pos: {line: 1, col: 1}}, {token: Ident(\"main\"), pos: {line: 1, col: 5}}, {token: LParen, pos: {line: 1, col: 9}}, {token: RParen, pos: {line: 1, col: 10}}, {token: LBrace, pos: {line: 1, col: 12}}, {token: KwReturn, pos: {line: 1, col: 14}}, {token: IntLit(42), pos: {line: 1, col: 21}}, {token: Semi, pos: {line: 1, col: 23}}, {token: RBrace, pos: {line: 1, col: 25}}, {token: Eof, pos: {line: 1, col: 26}}])",
  )
}
