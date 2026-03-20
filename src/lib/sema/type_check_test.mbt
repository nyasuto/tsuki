// === is_assignable テスト ===

test "is_assignable: Int to Int" {
  inspect(is_assignable(@ast.CType::Int, @ast.CType::Int), content="true")
}

test "is_assignable: Char to Char" {
  inspect(is_assignable(@ast.CType::Char, @ast.CType::Char), content="true")
}

test "is_assignable: Char to Int (implicit conversion)" {
  inspect(is_assignable(@ast.CType::Int, @ast.CType::Char), content="true")
}

test "is_assignable: Int to Char (implicit conversion)" {
  inspect(is_assignable(@ast.CType::Char, @ast.CType::Int), content="true")
}

test "is_assignable: Ptr(Int) to Ptr(Int)" {
  inspect(
    is_assignable(@ast.CType::Ptr(@ast.CType::Int), @ast.CType::Ptr(@ast.CType::Int)),
    content="true",
  )
}

test "is_assignable: Ptr(Char) to Ptr(Int) is false" {
  inspect(
    is_assignable(@ast.CType::Ptr(@ast.CType::Int), @ast.CType::Ptr(@ast.CType::Char)),
    content="false",
  )
}

test "is_assignable: Void to Int is false" {
  inspect(is_assignable(@ast.CType::Int, @ast.CType::Void), content="false")
}

test "is_assignable: Int to Void is false" {
  inspect(is_assignable(@ast.CType::Void, @ast.CType::Int), content="false")
}

test "is_assignable: Int to Ptr (C allows)" {
  inspect(
    is_assignable(@ast.CType::Ptr(@ast.CType::Int), @ast.CType::Int),
    content="true",
  )
}

test "is_assignable: Struct same name" {
  inspect(
    is_assignable(@ast.CType::Struct("Point"), @ast.CType::Struct("Point")),
    content="true",
  )
}

test "is_assignable: Struct different name" {
  inspect(
    is_assignable(@ast.CType::Struct("Point"), @ast.CType::Struct("Rect")),
    content="false",
  )
}

// === TypeChecker: 正常ケースのテスト ===

test "TypeChecker: simple return 42" {
  // int main() { return 42; }
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "main",
        [],
        Block([Return(Some(IntLiteral(42)))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
}

test "TypeChecker: return with variable" {
  // int main() { int x = 10; return x; }
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "main",
        [],
        Block([VarDecl("int", "x", Some(IntLiteral(10))), Return(Some(Ident("x")))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
}

test "TypeChecker: function call with matching args" {
  // int add(int a, int b) { return a + b; }
  // int main() { return add(3, 4); }
  let program : @ast.Program = {
    top_levels: [
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
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
}

test "TypeChecker: char to int assignment" {
  // int main() { int x = 'a'; return x; }
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "main",
        [],
        Block(
          [VarDecl("int", "x", Some(CharLiteral('a'))), Return(Some(Ident("x")))],
        ),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
}

test "TypeChecker: void function with no return value" {
  // void nop() { return; }
  let program : @ast.Program = {
    top_levels: [FuncDef("void", "nop", [], Block([Return(None)]))],
  }
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
}

test "TypeChecker: if-else type check" {
  // int abs(int x) { if (x < 0) return -x; else return x; }
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "abs",
        [{ type_name: "int", name: "x" }],
        Block(
          [
            If(
              BinaryOp(Lt, Ident("x"), IntLiteral(0)),
              Return(Some(UnaryOp(Neg, Ident("x")))),
              Some(Return(Some(Ident("x")))),
            ),
          ],
        ),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
}

// === TypeChecker: エラーケースのテスト ===

test "TypeChecker: void function returns value" {
  // void f() { return 42; }
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "void",
        "f",
        [],
        Block([Return(Some(IntLiteral(42)))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(
    tc.check_program(program),
    content="Err(\"void function should not return a value\")",
  )
}

test "TypeChecker: undefined variable" {
  // int main() { return x; }
  let program : @ast.Program = {
    top_levels: [
      FuncDef("int", "main", [], Block([Return(Some(Ident("x")))])),
    ],
  }
  let tc = TypeChecker::new()
  inspect(
    tc.check_program(program),
    content="Err(\"undefined variable: 'x'\")",
  )
}

test "TypeChecker: undefined function call" {
  // int main() { return foo(); }
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "main",
        [],
        Block([Return(Some(Call("foo", [])))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(
    tc.check_program(program),
    content="Err(\"undefined function: 'foo'\")",
  )
}

test "TypeChecker: wrong number of arguments" {
  // int add(int a, int b) { return a + b; }
  // int main() { return add(1); }
  let program : @ast.Program = {
    top_levels: [
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
        Block([Return(Some(Call("add", [IntLiteral(1)])))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(
    tc.check_program(program),
    content="Err(\"function 'add' expects 2 arguments, got 1\")",
  )
}

test "TypeChecker: variable redefinition in same scope" {
  // int main() { int x = 1; int x = 2; return x; }
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "main",
        [],
        Block(
          [
            VarDecl("int", "x", Some(IntLiteral(1))),
            VarDecl("int", "x", Some(IntLiteral(2))),
            Return(Some(Ident("x"))),
          ],
        ),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(
    tc.check_program(program),
    content="Err(\"redefinition of 'x'\")",
  )
}

test "TypeChecker: calling a variable as function" {
  // int main() { int x = 1; return x(); }
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "main",
        [],
        Block(
          [VarDecl("int", "x", Some(IntLiteral(1))), Return(Some(Call("x", [])))],
        ),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(
    tc.check_program(program),
    content="Err(\"'x' is not a function\")",
  )
}

// === infer_expr テスト ===

test "TypeChecker: infer_expr IntLiteral" {
  let tc = TypeChecker::new()
  inspect(tc.infer_expr(IntLiteral(42)), content="Ok(Int)")
}

test "TypeChecker: infer_expr CharLiteral" {
  let tc = TypeChecker::new()
  inspect(tc.infer_expr(CharLiteral('a')), content="Ok(Char)")
}

test "TypeChecker: infer_expr StringLiteral" {
  let tc = TypeChecker::new()
  inspect(tc.infer_expr(StringLiteral("hello")), content="Ok(Ptr(Char))")
}

test "TypeChecker: infer_expr BinaryOp arithmetic" {
  let tc = TypeChecker::new()
  inspect(
    tc.infer_expr(BinaryOp(Add, IntLiteral(1), IntLiteral(2))),
    content="Ok(Int)",
  )
}

test "TypeChecker: infer_expr comparison" {
  let tc = TypeChecker::new()
  inspect(
    tc.infer_expr(BinaryOp(Lt, IntLiteral(1), IntLiteral(2))),
    content="Ok(Int)",
  )
}

test "TypeChecker: infer_expr UnaryOp Neg" {
  let tc = TypeChecker::new()
  inspect(tc.infer_expr(UnaryOp(Neg, IntLiteral(1))), content="Ok(Int)")
}

test "TypeChecker: infer_expr UnaryOp AddrOf" {
  let tc = TypeChecker::new()
  let _ = tc.symbols.add_symbol("x", Variable(@ast.CType::Int))
  inspect(tc.infer_expr(UnaryOp(AddrOf, Ident("x"))), content="Ok(Ptr(Int))")
}

test "TypeChecker: infer_expr UnaryOp Deref" {
  let tc = TypeChecker::new()
  let _ = tc.symbols.add_symbol(
    "p",
    Variable(@ast.CType::Ptr(@ast.CType::Int)),
  )
  inspect(tc.infer_expr(UnaryOp(Deref, Ident("p"))), content="Ok(Int)")
}

test "TypeChecker: deref non-pointer is error" {
  let tc = TypeChecker::new()
  let _ = tc.symbols.add_symbol("x", Variable(@ast.CType::Int))
  inspect(
    tc.infer_expr(UnaryOp(Deref, Ident("x"))),
    content="Err(\"cannot dereference non-pointer type: Int\")",
  )
}

// === TypeChecker: 構造体のテスト ===

test "TypeChecker: struct definition registration" {
  // struct Point { int x; int y; };
  // int main() { return 0; }
  let program : @ast.Program = {
    top_levels: [
      StructDef(
        "Point",
        [{ type_name: "int", name: "x" }, { type_name: "int", name: "y" }],
      ),
      FuncDef(
        "int",
        "main",
        [],
        Block([Return(Some(IntLiteral(0)))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
  // 構造体が登録されていることを確認
  inspect(tc.symbols.lookup_struct("Point").is_empty(), content="false")
}

test "TypeChecker: struct variable declaration" {
  // struct Point { int x; int y; };
  // int main() { struct Point p; return 0; }
  let program : @ast.Program = {
    top_levels: [
      StructDef(
        "Point",
        [{ type_name: "int", name: "x" }, { type_name: "int", name: "y" }],
      ),
      FuncDef(
        "int",
        "main",
        [],
        Block([VarDecl("struct Point", "p", None), Return(Some(IntLiteral(0)))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
}

test "TypeChecker: struct pointer parameter" {
  // struct Point { int x; int y; };
  // int get_x(struct Point* p) { return 0; }
  // int main() { return 0; }
  let program : @ast.Program = {
    top_levels: [
      StructDef(
        "Point",
        [{ type_name: "int", name: "x" }, { type_name: "int", name: "y" }],
      ),
      FuncDef(
        "int",
        "get_x",
        [{ type_name: "struct Point*", name: "p" }],
        Block([Return(Some(IntLiteral(0)))]),
      ),
      FuncDef(
        "int",
        "main",
        [],
        Block([Return(Some(IntLiteral(0)))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  inspect(tc.check_program(program), content="Ok(())")
}

// === 型付き AST 変換テスト ===

test "transform_expr: IntLiteral has type Int" {
  let tc = TypeChecker::new()
  let result = tc.transform_expr(@ast.Expr::IntLiteral(42))
  inspect(result, content="Ok({kind: IntLiteral(42), ty: Int})")
}

test "transform_expr: CharLiteral has type Char" {
  let tc = TypeChecker::new()
  let result = tc.transform_expr(@ast.Expr::CharLiteral('a'))
  inspect(result, content="Ok({kind: CharLiteral('a'), ty: Char})")
}

test "transform_expr: StringLiteral has type Ptr(Char)" {
  let tc = TypeChecker::new()
  let result = tc.transform_expr(@ast.Expr::StringLiteral("hello"))
  inspect(
    result,
    content="Ok({kind: StringLiteral(\"hello\"), ty: Ptr(Char)})",
  )
}

test "transform_expr: BinaryOp Add preserves typed children" {
  let tc = TypeChecker::new()
  let result = tc.transform_expr(
    @ast.Expr::BinaryOp(Add, IntLiteral(1), IntLiteral(2)),
  )
  inspect(
    result,
    content="Ok({kind: BinaryOp(Add, {kind: IntLiteral(1), ty: Int}, {kind: IntLiteral(2), ty: Int}), ty: Int})",
  )
}

test "transform_expr: UnaryOp AddrOf yields Ptr type" {
  let tc = TypeChecker::new()
  let _ = tc.symbols.add_symbol("x", Variable(@ast.CType::Int))
  let result = tc.transform_expr(@ast.Expr::UnaryOp(AddrOf, Ident("x")))
  inspect(
    result,
    content="Ok({kind: UnaryOp(AddrOf, {kind: Ident(\"x\"), ty: Int}), ty: Ptr(Int)})",
  )
}

test "transform_expr: Call returns typed args and return type" {
  let tc = TypeChecker::new()
  let _ = tc.symbols.add_symbol(
    "add",
    Function(@ast.CType::Int, [@ast.CType::Int, @ast.CType::Int]),
  )
  let result = tc.transform_expr(
    @ast.Expr::Call("add", [IntLiteral(3), IntLiteral(4)]),
  )
  inspect(
    result,
    content="Ok({kind: Call(\"add\", [{kind: IntLiteral(3), ty: Int}, {kind: IntLiteral(4), ty: Int}]), ty: Int})",
  )
}

test "transform_expr: Ident resolves variable type" {
  let tc = TypeChecker::new()
  let _ = tc.symbols.add_symbol(
    "p",
    Variable(@ast.CType::Ptr(@ast.CType::Int)),
  )
  let result = tc.transform_expr(@ast.Expr::Ident("p"))
  inspect(result, content="Ok({kind: Ident(\"p\"), ty: Ptr(Int)})")
}

test "transform_program: simple return 42 produces typed AST" {
  let program : @ast.Program = {
    top_levels: [
      FuncDef("int", "main", [], Block([Return(Some(IntLiteral(42)))])),
    ],
  }
  let tc = TypeChecker::new()
  let result = tc.transform_program(program)
  let expected = "Ok({top_levels: [FuncDef(Int, \"main\", [], Block([Return(Some({kind: IntLiteral(42), ty: Int}))]))]})";
  inspect(result, content=expected)
}

test "transform_program: function with params produces typed params" {
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int",
        "add",
        [{ type_name: "int", name: "a" }, { type_name: "int", name: "b" }],
        Block([Return(Some(BinaryOp(Add, Ident("a"), Ident("b"))))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  let result = tc.transform_program(program)
  let expected = "Ok({top_levels: [FuncDef(Int, \"add\", [{ty: Int, name: \"a\"}, {ty: Int, name: \"b\"}], Block([Return(Some({kind: BinaryOp(Add, {kind: Ident(\"a\"), ty: Int}, {kind: Ident(\"b\"), ty: Int}), ty: Int}))]))]})";
  inspect(result, content=expected)
}

test "transform_program: VarDecl resolves type from string to CType" {
  let program : @ast.Program = {
    top_levels: [
      FuncDef(
        "int", "main", [],
        Block([VarDecl("int", "x", Some(IntLiteral(42))), Return(Some(Ident("x")))]),
      ),
    ],
  }
  let tc = TypeChecker::new()
  let result = tc.transform_program(program)
  let expected = "Ok({top_levels: [FuncDef(Int, \"main\", [], Block([VarDecl(Int, \"x\", Some({kind: IntLiteral(42), ty: Int})), Return(Some({kind: Ident(\"x\"), ty: Int}))]))]})";
  inspect(result, content=expected)
}

test "transform_program: struct def becomes StructDef with name only" {
  let program : @ast.Program = {
    top_levels: [
      StructDef(
        "Point",
        [{ type_name: "int", name: "x" }, { type_name: "int", name: "y" }],
      ),
      FuncDef("int", "main", [], Block([Return(Some(IntLiteral(0)))])),
    ],
  }
  let tc = TypeChecker::new()
  let result = tc.transform_program(program)
  let expected = "Ok({top_levels: [StructDef(\"Point\"), FuncDef(Int, \"main\", [], Block([Return(Some({kind: IntLiteral(0), ty: Int}))]))]})";
  inspect(result, content=expected)
}

// === sizeof 演算子の型チェック・変換テスト ===

test "transform_expr: sizeof(int) → IntLiteral(4)" {
  let tc = TypeChecker::new()
  let result = tc.transform_expr(@ast.Expr::SizeOf("int"))
  inspect(result, content="Ok({kind: IntLiteral(4), ty: Int})")
}

test "transform_expr: sizeof(char) → IntLiteral(1)" {
  let tc = TypeChecker::new()
  let result = tc.transform_expr(@ast.Expr::SizeOf("char"))
  inspect(result, content="Ok({kind: IntLiteral(1), ty: Int})")
}

test "transform_expr: sizeof(int*) → IntLiteral(4)" {
  let tc = TypeChecker::new()
  let result = tc.transform_expr(@ast.Expr::SizeOf("int*"))
  inspect(result, content="Ok({kind: IntLiteral(4), ty: Int})")
}

test "transform_expr: sizeof(struct Point) with registered struct" {
  let tc = TypeChecker::new()
  let fields : Array[@ast.StructField] = [
    { type_name: "int", name: "x" },
    { type_name: "int", name: "y" },
  ]
  let _ = tc.symbols.register_struct("Point", fields)
  let result = tc.transform_expr(@ast.Expr::SizeOf("struct Point"))
  inspect(result, content="Ok({kind: IntLiteral(8), ty: Int})")
}

test "transform_expr: sizeof(void) → error" {
  let tc = TypeChecker::new()
  let result = tc.transform_expr(@ast.Expr::SizeOf("void"))
  inspect(result, content="Err(\"cannot compute size of void\")")
}
