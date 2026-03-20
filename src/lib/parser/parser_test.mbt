test "Parser::new creates parser at position 0" {
  let tokens : Array[@lexer.LocToken] = [
    { token: @lexer.Token::IntLit(42), pos: { line: 1, col: 1 } },
    { token: @lexer.Token::Eof, pos: { line: 1, col: 3 } },
  ]
  let parser = @parser.Parser::new(tokens)
  inspect(parser.peek(), content="IntLit(42)")
}

test "advance consumes token and moves forward" {
  let tokens : Array[@lexer.LocToken] = [
    { token: @lexer.Token::KwInt, pos: { line: 1, col: 1 } },
    { token: @lexer.Token::Ident("main"), pos: { line: 1, col: 5 } },
    { token: @lexer.Token::Eof, pos: { line: 1, col: 9 } },
  ]
  let parser = @parser.Parser::new(tokens)
  let tok1 = parser.advance()
  inspect(tok1, content="KwInt")
  let tok2 = parser.advance()
  inspect(tok2, content="Ident(\"main\")")
  let tok3 = parser.advance()
  inspect(tok3, content="Eof")
  // advance past EOF still returns Eof
  let tok4 = parser.advance()
  inspect(tok4, content="Eof")
}

test "peek does not consume token" {
  let tokens : Array[@lexer.LocToken] = [
    { token: @lexer.Token::Plus, pos: { line: 1, col: 1 } },
    { token: @lexer.Token::Eof, pos: { line: 1, col: 2 } },
  ]
  let parser = @parser.Parser::new(tokens)
  inspect(parser.peek(), content="Plus")
  inspect(parser.peek(), content="Plus")
  // position unchanged
  let _ = parser.advance()
  inspect(parser.peek(), content="Eof")
}

test "expect succeeds on matching token" {
  let tokens : Array[@lexer.LocToken] = [
    { token: @lexer.Token::LParen, pos: { line: 1, col: 1 } },
    { token: @lexer.Token::RParen, pos: { line: 1, col: 2 } },
    { token: @lexer.Token::Eof, pos: { line: 1, col: 3 } },
  ]
  let parser = @parser.Parser::new(tokens)
  let r1 = parser.expect(@lexer.Token::LParen)
  inspect(r1, content="Ok(())")
  let r2 = parser.expect(@lexer.Token::RParen)
  inspect(r2, content="Ok(())")
}

test "expect fails on mismatched token with position info" {
  let tokens : Array[@lexer.LocToken] = [
    { token: @lexer.Token::Semi, pos: { line: 3, col: 10 } },
    { token: @lexer.Token::Eof, pos: { line: 3, col: 11 } },
  ]
  let parser = @parser.Parser::new(tokens)
  let result = parser.expect(@lexer.Token::LBrace)
  inspect(
    result,
    content="Err(\"expected LBrace, got Semi at line 3, col 10\")",
  )
}

test "empty token array returns Eof" {
  let tokens : Array[@lexer.LocToken] = []
  let parser = @parser.Parser::new(tokens)
  inspect(parser.peek(), content="Eof")
  inspect(parser.advance(), content="Eof")
}
