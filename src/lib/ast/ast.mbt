/// C の型
pub(all) enum CType {
  Int                   // int
  Char                  // char
  Void                  // void
  Ptr(CType)            // ポインタ: T*
  Struct(String)        // 構造体: struct Name
  Array(CType, Int)     // 配列: T[N]
} derive(Show, Eq)

/// 二項演算子
pub(all) enum BinOp {
  Add       // +
  Sub       // -
  Mul       // *
  Div       // /
  Mod       // %
  Eq        // ==
  Ne        // !=
  Lt        // <
  Gt        // >
  Le        // <=
  Ge        // >=
  LogAnd    // &&
  LogOr     // ||
  BitAnd    // &
  BitOr     // |
  BitXor    // ^
  Shl       // <<
  Shr       // >>
} derive(Show, Eq)

/// 単項演算子
pub(all) enum UnaryOp {
  Neg       // -
  LogNot    // !
  BitNot    // ~
  Deref     // *
  AddrOf    // &
  PreInc    // ++x（前置インクリメント）
  PreDec    // --x（前置デクリメント）
  PostInc   // x++（後置インクリメント）
  PostDec   // x--（後置デクリメント）
} derive(Show, Eq)

/// 式の種類
pub(all) enum ExprKind {
  IntLiteral(Int)                           // 整数リテラル
  CharLiteral(Char)                         // 文字リテラル
  StringLiteral(String)                     // 文字列リテラル
  Ident(String)                             // 識別子
  BinaryOp(BinOp, Expr, Expr)              // 二項演算: op, lhs, rhs
  UnaryOp(UnaryOp, Expr)                   // 単項演算: op, operand
  Call(String, Array[Expr])                 // 関数呼び出し: name, args
  Assign(Expr, Expr)                       // 代入: lhs, rhs
  MemberAccess(Expr, String)               // メンバアクセス: base.field
  SizeOf(String)                           // sizeof(型名): 型名文字列
  InitList(Array[Expr])                    // 初期化リスト: {expr, expr, ...}
} derive(Show, Eq)

/// 式: 位置情報付き
pub(all) struct Expr {
  kind : ExprKind
  pos : @lexer.Pos
}

/// Expr の Show は kind のみ表示（テスト互換性のため pos は省略）
pub impl Show for Expr with output(self, logger) {
  Show::output(self.kind, logger)
}

/// Expr の Eq は kind のみ比較（pos は無視）
pub impl Eq for Expr with equal(self, other) -> Bool {
  self.kind == other.kind
}

/// テスト用: ダミー位置で Expr を作成する
pub fn Expr::mk(kind : ExprKind) -> Expr {
  { kind, pos: { line: 0, col: 0 } }
}

/// 文の種類
pub(all) enum StmtKind {
  Return(Expr?)                        // return 文: 式（void 関数では None）
  VarDecl(String, String, Expr?)       // 変数宣言: 型名, 変数名, 初期値
  ExprStmt(Expr)                       // 式文
  Block(Array[Stmt])                   // ブロック: 文のリスト
  If(Expr, Stmt, Stmt?)               // if 文: 条件, then 節, else 節
  While(Expr, Stmt)                    // while 文: 条件, 本体
  For(Stmt?, Expr?, Expr?, Stmt)       // for 文: 初期化, 条件, 更新, 本体
} derive(Show, Eq)

/// 文: 位置情報付き
pub(all) struct Stmt {
  kind : StmtKind
  pos : @lexer.Pos
}

/// Stmt の Show は kind のみ表示（テスト互換性のため pos は省略）
pub impl Show for Stmt with output(self, logger) {
  Show::output(self.kind, logger)
}

/// Stmt の Eq は kind のみ比較（pos は無視）
pub impl Eq for Stmt with equal(self, other) -> Bool {
  self.kind == other.kind
}

/// テスト用: ダミー位置で Stmt を作成する
pub fn Stmt::mk(kind : StmtKind) -> Stmt {
  { kind, pos: { line: 0, col: 0 } }
}

/// パラメータ: 型名と変数名のペア
pub(all) struct Param {
  type_name : String
  name : String
} derive(Show, Eq)

/// 構造体フィールド: 型名とフィールド名のペア
pub(all) struct StructField {
  type_name : String
  name : String
} derive(Show, Eq)

/// トップレベル定義
pub(all) enum TopLevel {
  FuncDef(String, String, Array[Param], Stmt)       // 関数定義: 戻り値型, 関数名, パラメータ, 本体(Block)
  GlobalVarDecl(String, String, Expr?)               // グローバル変数宣言: 型名, 変数名, 初期値
  StructDef(String, Array[StructField])              // 構造体定義: 構造体名, フィールドリスト
} derive(Show, Eq)

/// プログラム: トップレベル定義のリスト
pub(all) struct Program {
  top_levels : Array[TopLevel]
} derive(Show, Eq)

// ============================================================
// 型付き AST: 意味解析（Sema）で各ノードに解決済み型を付与した AST
// ============================================================

/// 型付き式: 解決済みの型情報を持つ式ノード
pub(all) struct TypedExpr {
  kind : TypedExprKind
  ty : CType
} derive(Show, Eq)

/// 型付き式の種類
pub(all) enum TypedExprKind {
  IntLiteral(Int)                        // 整数リテラル
  CharLiteral(Char)                      // 文字リテラル
  StringLiteral(String)                  // 文字列リテラル
  Ident(String)                          // 識別子
  BinaryOp(BinOp, TypedExpr, TypedExpr) // 二項演算: op, lhs, rhs
  UnaryOp(UnaryOp, TypedExpr)           // 単項演算: op, operand
  Call(String, Array[TypedExpr])         // 関数呼び出し: name, args
  Assign(TypedExpr, TypedExpr)          // 代入: lhs, rhs
  MemberAccess(TypedExpr, String)       // メンバアクセス: base.field
  SizeOf(CType)                         // sizeof(型): 解決済み型
  InitList(Array[TypedExpr])            // 初期化リスト: {expr, expr, ...}
} derive(Show, Eq)

/// 型付き文
pub(all) enum TypedStmt {
  Return(TypedExpr?)                                   // return 文
  VarDecl(CType, String, TypedExpr?)                   // 変数宣言: 解決済み型, 変数名, 初期値
  ExprStmt(TypedExpr)                                  // 式文
  Block(Array[TypedStmt])                              // ブロック
  If(TypedExpr, TypedStmt, TypedStmt?)                // if 文: 条件, then, else
  While(TypedExpr, TypedStmt)                          // while 文: 条件, 本体
  For(TypedStmt?, TypedExpr?, TypedExpr?, TypedStmt)  // for 文: init, cond, update, body
} derive(Show, Eq)

/// 型付きパラメータ: 解決済み型と変数名
pub(all) struct TypedParam {
  ty : CType
  name : String
} derive(Show, Eq)

/// 型付きトップレベル定義
pub(all) enum TypedTopLevel {
  FuncDef(CType, String, Array[TypedParam], TypedStmt)  // 戻り値型, 関数名, パラメータ, 本体
  GlobalVarDecl(CType, String, TypedExpr?)               // 解決済み型, 変数名, 初期値
  StructDef(String)                                       // 構造体名（レイアウト情報は SymbolTable から参照）
} derive(Show, Eq)

/// 型付きプログラム
pub(all) struct TypedProgram {
  top_levels : Array[TypedTopLevel]
} derive(Show, Eq)

/// CType を C スタイルの文字列に変換する（エラーメッセージ用）
/// 例: Int → "int", Ptr(Int) → "int*", Struct("Point") → "struct Point", Array(Int, 10) → "int[10]"
pub fn format_type(ty : CType) -> String {
  match ty {
    Int => "int"
    Char => "char"
    Void => "void"
    Ptr(inner) => format_type(inner) + "*"
    Struct(name) => "struct " + name
    Array(elem, size) => format_type(elem) + "[" + size.to_string() + "]"
  }
}

/// 位置情報のフォーマット（{0,0} の場合は空文字列）
pub fn format_pos(pos : @lexer.Pos) -> String {
  if pos.line == 0 && pos.col == 0 {
    ""
  } else {
    " at line " + pos.line.to_string() + ", col " + pos.col.to_string()
  }
}
