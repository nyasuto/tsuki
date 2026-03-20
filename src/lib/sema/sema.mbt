/// シンボルの種類
pub(all) enum SymbolKind {
  /// 変数: 型情報
  Variable(@ast.CType)
  /// 関数: 戻り値型, パラメータ型リスト
  Function(@ast.CType, Array[@ast.CType])
} derive(Show, Eq)

/// シンボルテーブルのエントリ
pub(all) struct Symbol {
  name : String
  kind : SymbolKind
  scope_depth : Int
} derive(Show, Eq)

/// スコープ: 1つのスコープレベル
struct Scope {
  symbols : Map[String, Symbol]
  depth : Int
}

/// シンボルテーブル: スコープチェインを管理
/// グローバル → 関数 → ブロック の階層構造
pub struct SymbolTable {
  scopes : Array[Scope]
}

/// 型名文字列から CType への変換
pub fn resolve_type_name(name : String) -> Result[@ast.CType, String] {
  // ポインタ型の処理: "int*", "char*" など
  if name.length() > 0 && name[name.length() - 1] == '*' {
    let base_name = name[0 : name.length() - 1].to_string()
    // 再帰的に解決（多重ポインタ対応: "int**" → Ptr(Ptr(Int))）
    match resolve_type_name(base_name) {
      Ok(base_type) => Ok(@ast.CType::Ptr(base_type))
      Err(e) => Err(e)
    }
  } else {
    match name {
      "int" => Ok(@ast.CType::Int)
      "char" => Ok(@ast.CType::Char)
      "void" => Ok(@ast.CType::Void)
      _ => Err("unknown type: " + name)
    }
  }
}

/// 新しいシンボルテーブルを作成（グローバルスコープで初期化）
pub fn SymbolTable::new() -> SymbolTable {
  let global_scope : Scope = { symbols: Map::new(), depth: 0 }
  { scopes: [global_scope] }
}

/// 現在のスコープの深さを返す
pub fn SymbolTable::current_depth(self : SymbolTable) -> Int {
  self.scopes[self.scopes.length() - 1].depth
}

/// 新しいスコープを開始する（ブロックに入る時）
pub fn SymbolTable::enter_scope(self : SymbolTable) -> Unit {
  let new_depth = self.current_depth() + 1
  let scope : Scope = { symbols: Map::new(), depth: new_depth }
  self.scopes.push(scope)
}

/// 現在のスコープを終了する（ブロックから出る時）
/// グローバルスコープは削除できない
pub fn SymbolTable::leave_scope(self : SymbolTable) -> Result[Unit, String] {
  if self.scopes.length() <= 1 {
    Err("cannot leave global scope")
  } else {
    let _ = self.scopes.pop()
    Ok(())
  }
}

/// 現在のスコープにシンボルを定義する
/// 同じスコープ内での重複定義はエラー
pub fn SymbolTable::add_symbol(
  self : SymbolTable,
  name : String,
  kind : SymbolKind
) -> Result[Symbol, String] {
  let current = self.scopes[self.scopes.length() - 1]
  match current.symbols.get(name) {
    Some(_) => Err("redefinition of '" + name + "'")
    None => {
      let symbol : Symbol = { name, kind, scope_depth: current.depth }
      current.symbols.set(name, symbol)
      Ok(symbol)
    }
  }
}

/// シンボルを検索する（内側のスコープから外側へ）
pub fn SymbolTable::lookup(self : SymbolTable, name : String) -> Option[Symbol] {
  let len = self.scopes.length()
  for i = len - 1; i >= 0; i = i - 1 {
    match self.scopes[i].symbols.get(name) {
      Some(sym) => return Some(sym)
      None => ()
    }
  }
  None
}

/// 現在のスコープのみでシンボルを検索する（重複チェック用）
pub fn SymbolTable::lookup_current_scope(
  self : SymbolTable,
  name : String
) -> Option[Symbol] {
  let current = self.scopes[self.scopes.length() - 1]
  current.symbols.get(name)
}
