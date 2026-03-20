fn e(kind : @ast.ExprKind) -> @ast.Expr {
  @ast.Expr::mk(kind)
}

fn s(kind : @ast.StmtKind) -> @ast.Stmt {
  @ast.Stmt::mk(kind)
}

test "Program with single function" {
  let prog : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "main",
        [],
        s(Block([s(Return(Some(e(IntLiteral(42)))))])),
      ),
    ],
  }
  inspect(
    prog,
    content="{top_levels: [FuncDef(\"int\", \"main\", [], Block([Return(Some(IntLiteral(42)))]))]}"
  )
}

test "Program with multiple top-levels" {
  let prog : @ast.Program = {
    top_levels: [
      GlobalVarDecl("int", "g", Some(e(IntLiteral(100)))),
      FuncDef(
        "int",
        "add",
        [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
        s(Block([s(Return(Some(e(BinaryOp(Add, e(Ident("a")), e(Ident("b")))))))])),
      ),
      FuncDef(
        "int",
        "main",
        [],
        s(Block([s(Return(Some(e(Call("add", [e(IntLiteral(3)), e(IntLiteral(4))])))))])),
      ),
    ],
  }
  inspect(prog.top_levels.length(), content="3")
}

test "Program with empty top-levels" {
  let prog : @ast.Program = { top_levels: [] }
  inspect(prog.top_levels.length(), content="0")
}

// === format_type テスト ===

test "format_type: Int → int" {
  inspect(@ast.format_type(@ast.CType::Int), content="int")
}

test "format_type: Char → char" {
  inspect(@ast.format_type(@ast.CType::Char), content="char")
}

test "format_type: Void → void" {
  inspect(@ast.format_type(@ast.CType::Void), content="void")
}

test "format_type: Ptr(Int) → int*" {
  inspect(@ast.format_type(@ast.CType::Ptr(@ast.CType::Int)), content="int*")
}

test "format_type: Ptr(Ptr(Char)) → char**" {
  inspect(
    @ast.format_type(@ast.CType::Ptr(@ast.CType::Ptr(@ast.CType::Char))),
    content="char**",
  )
}

test "format_type: Struct(Point) → struct Point" {
  inspect(@ast.format_type(@ast.CType::Struct("Point")), content="struct Point")
}

test "format_type: Ptr(Struct(Point)) → struct Point*" {
  inspect(
    @ast.format_type(@ast.CType::Ptr(@ast.CType::Struct("Point"))),
    content="struct Point*",
  )
}

test "format_type: Array(Int, 10) → int[10]" {
  inspect(
    @ast.format_type(@ast.CType::Array(@ast.CType::Int, 10)),
    content="int[10]",
  )
}
