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
