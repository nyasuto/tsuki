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
