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

/// 構造体フィールドの解決済み情報
pub(all) struct StructFieldInfo {
  name : String
  field_type : @ast.CType
  offset : Int
} derive(Show, Eq)

/// 構造体のレイアウト情報
pub(all) struct StructInfo {
  name : String
  fields : Array[StructFieldInfo]
  total_size : Int
} derive(Show, Eq)

/// シンボルテーブル: スコープチェインを管理
/// グローバル → 関数 → ブロック の階層構造
pub struct SymbolTable {
  scopes : Array[Scope]
  /// 構造体定義のレジストリ（名前 → レイアウト情報）
  struct_defs : Map[String, StructInfo]
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
  } else if name.length() > 7 && name[0:7].to_string() == "struct " {
    // 構造体型: "struct Name" → Struct("Name")
    let struct_name = name[7:name.length()].to_string()
    Ok(@ast.CType::Struct(struct_name))
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
  { scopes: [global_scope], struct_defs: Map::new() }
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

/// 型のサイズを返す（バイト単位）
pub fn size_of(
  self : SymbolTable,
  ty : @ast.CType
) -> Result[Int, String] {
  match ty {
    Int => Ok(4)
    Char => Ok(1)
    Void => Err("cannot compute size of void")
    Ptr(_) => Ok(4) // Wasm i32
    Struct(name) =>
      match self.lookup_struct(name) {
        Some(info) => Ok(info.total_size)
        None => Err("undefined struct: '" + name + "'")
      }
    Array(elem, count) =>
      match self.size_of(elem) {
        Ok(elem_size) => Ok(elem_size * count)
        Err(e) => Err(e)
      }
  }
}

/// 4バイトアライメントに切り上げる
fn align4(offset : Int) -> Int {
  (offset + 3) / 4 * 4
}

/// 構造体のフィールドレイアウトを計算して登録する
/// 各フィールドは 4 バイトアライメント
pub fn SymbolTable::register_struct(
  self : SymbolTable,
  name : String,
  fields : Array[@ast.StructField]
) -> Result[StructInfo, String] {
  // 重複定義チェック
  match self.struct_defs.get(name) {
    Some(_) => return Err("redefinition of struct '" + name + "'")
    None => ()
  }
  let field_infos : Array[StructFieldInfo] = []
  let mut current_offset = 0
  for f in fields {
    // フィールドの型を解決
    let field_type = match resolve_type_name(f.type_name) {
      Ok(t) => t
      Err(e) => return Err(e)
    }
    // フィールドのサイズを計算
    let field_size = match self.size_of(field_type) {
      Ok(s) => s
      Err(e) => return Err(e)
    }
    // 4バイトアライメント
    current_offset = align4(current_offset)
    let _ = field_size
    field_infos.push(
      StructFieldInfo::{
        name: f.name,
        field_type,
        offset: current_offset,
      },
    )
    current_offset = current_offset + field_size
  }
  // 構造体全体のサイズも 4 バイトアライメント
  let total_size = align4(current_offset)
  let info = StructInfo::{ name, fields: field_infos, total_size }
  self.struct_defs.set(name, info)
  Ok(info)
}

/// 構造体の定義を検索する
pub fn SymbolTable::lookup_struct(
  self : SymbolTable,
  name : String
) -> Option[StructInfo] {
  self.struct_defs.get(name)
}
