// === resolve_type_name テスト ===

test "resolve_type_name: int" {
  inspect(resolve_type_name("int"), content="Ok(Int)")
}

test "resolve_type_name: char" {
  inspect(resolve_type_name("char"), content="Ok(Char)")
}

test "resolve_type_name: void" {
  inspect(resolve_type_name("void"), content="Ok(Void)")
}

test "resolve_type_name: int*" {
  inspect(resolve_type_name("int*"), content="Ok(Ptr(Int))")
}

test "resolve_type_name: char**" {
  inspect(resolve_type_name("char**"), content="Ok(Ptr(Ptr(Char)))")
}

test "resolve_type_name: unknown type" {
  inspect(resolve_type_name("float"), content="Err(\"unknown type: float\")")
}

// === SymbolTable 基本テスト ===

test "SymbolTable: new creates global scope at depth 0" {
  let st = SymbolTable::new()
  inspect(st.current_depth(), content="0")
}

test "SymbolTable: enter_scope increases depth" {
  let st = SymbolTable::new()
  st.enter_scope()
  inspect(st.current_depth(), content="1")
  st.enter_scope()
  inspect(st.current_depth(), content="2")
}

test "SymbolTable: leave_scope decreases depth" {
  let st = SymbolTable::new()
  st.enter_scope()
  st.enter_scope()
  inspect(st.current_depth(), content="2")
  let _ = st.leave_scope()
  inspect(st.current_depth(), content="1")
  let _ = st.leave_scope()
  inspect(st.current_depth(), content="0")
}

test "SymbolTable: cannot leave global scope" {
  let st = SymbolTable::new()
  inspect(st.leave_scope(), content="Err(\"cannot leave global scope\")")
}

// === add_symbol / lookup テスト ===

test "SymbolTable: add and lookup variable" {
  let st = SymbolTable::new()
  let result = st.add_symbol("x", Variable(@ast.CType::Int))
  inspect(
    result,
    content="Ok({name: \"x\", kind: Variable(Int), scope_depth: 0})",
  )
  inspect(
    st.lookup("x"),
    content="Some({name: \"x\", kind: Variable(Int), scope_depth: 0})",
  )
}

test "SymbolTable: add and lookup function" {
  let st = SymbolTable::new()
  let result = st.add_symbol(
    "add",
    Function(@ast.CType::Int, [@ast.CType::Int, @ast.CType::Int]),
  )
  inspect(
    result,
    content="Ok({name: \"add\", kind: Function(Int, [Int, Int]), scope_depth: 0})",
  )
}

test "SymbolTable: lookup undefined returns None" {
  let st = SymbolTable::new()
  inspect(st.lookup("undefined_var"), content="None")
}

test "SymbolTable: redefinition in same scope is error" {
  let st = SymbolTable::new()
  let _ = st.add_symbol("x", Variable(@ast.CType::Int))
  inspect(
    st.add_symbol("x", Variable(@ast.CType::Char)),
    content="Err(\"redefinition of 'x'\")",
  )
}

// === スコープチェインテスト ===

test "SymbolTable: inner scope shadows outer" {
  let st = SymbolTable::new()
  // グローバルに x: int を定義
  let _ = st.add_symbol("x", Variable(@ast.CType::Int))
  // 内側のスコープで x: char を定義（シャドウイング）
  st.enter_scope()
  let _ = st.add_symbol("x", Variable(@ast.CType::Char))
  // 内側から検索すると char が見つかる
  inspect(
    st.lookup("x"),
    content="Some({name: \"x\", kind: Variable(Char), scope_depth: 1})",
  )
  // スコープを出ると int が見つかる
  let _ = st.leave_scope()
  inspect(
    st.lookup("x"),
    content="Some({name: \"x\", kind: Variable(Int), scope_depth: 0})",
  )
}

test "SymbolTable: inner scope can access outer symbols" {
  let st = SymbolTable::new()
  let _ = st.add_symbol("global_var", Variable(@ast.CType::Int))
  st.enter_scope() // 関数スコープ
  let _ = st.add_symbol("local_var", Variable(@ast.CType::Char))
  st.enter_scope() // ブロックスコープ
  // 3階層目から全てのスコープのシンボルにアクセス可能
  inspect(
    st.lookup("global_var"),
    content="Some({name: \"global_var\", kind: Variable(Int), scope_depth: 0})",
  )
  inspect(
    st.lookup("local_var"),
    content="Some({name: \"local_var\", kind: Variable(Char), scope_depth: 1})",
  )
}

test "SymbolTable: leaving scope removes inner symbols" {
  let st = SymbolTable::new()
  st.enter_scope()
  let _ = st.add_symbol("temp", Variable(@ast.CType::Int))
  inspect(st.lookup("temp").is_empty(), content="false")
  let _ = st.leave_scope()
  // スコープを出た後は見つからない
  inspect(st.lookup("temp").is_empty(), content="true")
}

// === lookup_current_scope テスト ===

test "SymbolTable: lookup_current_scope only searches current" {
  let st = SymbolTable::new()
  let _ = st.add_symbol("outer", Variable(@ast.CType::Int))
  st.enter_scope()
  // outer は現在のスコープにはない
  inspect(st.lookup_current_scope("outer"), content="None")
  // でも lookup なら見つかる
  inspect(st.lookup("outer").is_empty(), content="false")
}

// === 関数スコープのシミュレーション ===

test "SymbolTable: simulate function scope chain" {
  let st = SymbolTable::new()
  // グローバルスコープ: 関数を登録
  let _ = st.add_symbol(
    "add",
    Function(@ast.CType::Int, [@ast.CType::Int, @ast.CType::Int]),
  )
  // 関数スコープに入る
  st.enter_scope()
  // パラメータを登録
  let _ = st.add_symbol("a", Variable(@ast.CType::Int))
  let _ = st.add_symbol("b", Variable(@ast.CType::Int))
  // ブロックスコープに入る（関数本体）
  st.enter_scope()
  // ローカル変数を登録
  let _ = st.add_symbol("result", Variable(@ast.CType::Int))
  // 全てのシンボルにアクセスできる
  inspect(st.lookup("add").is_empty(), content="false")
  inspect(st.lookup("a").is_empty(), content="false")
  inspect(st.lookup("b").is_empty(), content="false")
  inspect(st.lookup("result").is_empty(), content="false")
  inspect(st.current_depth(), content="2")
  // ブロックスコープを出る
  let _ = st.leave_scope()
  inspect(st.lookup("result").is_empty(), content="true")
  inspect(st.lookup("a").is_empty(), content="false")
  // 関数スコープを出る
  let _ = st.leave_scope()
  inspect(st.lookup("a").is_empty(), content="true")
  inspect(st.lookup("add").is_empty(), content="false")
}

// === resolve_type_name: 構造体型 ===

test "resolve_type_name: struct Point" {
  inspect(resolve_type_name("struct Point"), content="Ok(Struct(\"Point\"))")
}

test "resolve_type_name: struct Point*" {
  inspect(
    resolve_type_name("struct Point*"),
    content="Ok(Ptr(Struct(\"Point\")))",
  )
}

// === 構造体レジストリのテスト ===

test "SymbolTable: register and lookup struct" {
  let st = SymbolTable::new()
  let fields : Array[@ast.StructField] = [
    { type_name: "int", name: "x" },
    { type_name: "int", name: "y" },
  ]
  let result = st.register_struct("Point", fields)
  inspect(
    result,
    content="Ok({name: \"Point\", fields: [{name: \"x\", field_type: Int, offset: 0}, {name: \"y\", field_type: Int, offset: 4}], total_size: 8})",
  )
  inspect(st.lookup_struct("Point").is_empty(), content="false")
}

test "SymbolTable: struct with char and int fields (alignment)" {
  let st = SymbolTable::new()
  let fields : Array[@ast.StructField] = [
    { type_name: "char", name: "c" },
    { type_name: "int", name: "n" },
  ]
  let result = st.register_struct("Mixed", fields)
  // char は 1 バイトだが、次のフィールドは 4 バイトアライメントで offset 4
  inspect(
    result,
    content="Ok({name: \"Mixed\", fields: [{name: \"c\", field_type: Char, offset: 0}, {name: \"n\", field_type: Int, offset: 4}], total_size: 8})",
  )
}

test "SymbolTable: struct with pointer field" {
  let st = SymbolTable::new()
  let fields : Array[@ast.StructField] = [
    { type_name: "int", name: "value" },
    { type_name: "int*", name: "next" },
  ]
  let result = st.register_struct("Node", fields)
  inspect(
    result,
    content="Ok({name: \"Node\", fields: [{name: \"value\", field_type: Int, offset: 0}, {name: \"next\", field_type: Ptr(Int), offset: 4}], total_size: 8})",
  )
}

test "SymbolTable: struct redefinition is error" {
  let st = SymbolTable::new()
  let fields : Array[@ast.StructField] = [{ type_name: "int", name: "x" }]
  let _ = st.register_struct("Point", fields)
  inspect(
    st.register_struct("Point", fields),
    content="Err(\"redefinition of struct 'Point'\")",
  )
}

test "SymbolTable: lookup undefined struct returns None" {
  let st = SymbolTable::new()
  inspect(st.lookup_struct("Unknown"), content="None")
}

test "SymbolTable: size_of basic types" {
  let st = SymbolTable::new()
  inspect(st.size_of(@ast.CType::Int), content="Ok(4)")
  inspect(st.size_of(@ast.CType::Char), content="Ok(1)")
  inspect(st.size_of(@ast.CType::Ptr(@ast.CType::Int)), content="Ok(4)")
  inspect(st.size_of(@ast.CType::Void), content="Err(\"cannot compute size of void\")")
}

test "SymbolTable: size_of struct" {
  let st = SymbolTable::new()
  let fields : Array[@ast.StructField] = [
    { type_name: "int", name: "x" },
    { type_name: "int", name: "y" },
  ]
  let _ = st.register_struct("Point", fields)
  inspect(st.size_of(@ast.CType::Struct("Point")), content="Ok(8)")
}

test "SymbolTable: nested struct field" {
  let st = SymbolTable::new()
  // まず Point を登録
  let _ = st.register_struct(
    "Point",
    [
      { type_name: "int", name: "x" },
      { type_name: "int", name: "y" },
    ],
  )
  // Point を含む構造体
  let result = st.register_struct(
    "Rect",
    [
      { type_name: "struct Point", name: "origin" },
      { type_name: "int", name: "width" },
      { type_name: "int", name: "height" },
    ],
  )
  inspect(
    result,
    content="Ok({name: \"Rect\", fields: [{name: \"origin\", field_type: Struct(\"Point\"), offset: 0}, {name: \"width\", field_type: Int, offset: 8}, {name: \"height\", field_type: Int, offset: 12}], total_size: 16})",
  )
}

// === resolve_type_name: 配列型 ===

test "resolve_type_name: int[10]" {
  inspect(resolve_type_name("int[10]"), content="Ok(Array(Int, 10))")
}

test "resolve_type_name: char[256]" {
  inspect(resolve_type_name("char[256]"), content="Ok(Array(Char, 256))")
}

test "resolve_type_name: int*[5]" {
  inspect(resolve_type_name("int*[5]"), content="Ok(Array(Ptr(Int), 5))")
}
