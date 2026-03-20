test "Program with single function" {
  let prog : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "main",
        [],
        Block([Return(Some(IntLiteral(42)))]),
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
      GlobalVarDecl("int", "g", Some(IntLiteral(100))),
      FuncDef(
        "int",
        "add",
        [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
        Block([Return(Some(BinaryOp(Add, Ident("a"), Ident("b"))))]),
      ),
      FuncDef(
        "int",
        "main",
        [],
        Block([Return(Some(Call("add", [IntLiteral(3), IntLiteral(4)])))]),
      ),
    ],
  }
  inspect(prog.top_levels.length(), content="3")
}

test "Program with empty top-levels" {
  let prog : @ast.Program = { top_levels: [] }
  inspect(prog.top_levels.length(), content="0")
}
