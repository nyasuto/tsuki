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

/// 式
pub(all) enum Expr {
  IntLiteral(Int)                        // 整数リテラル
  CharLiteral(Char)                      // 文字リテラル
  StringLiteral(String)                  // 文字列リテラル
  Ident(String)                          // 識別子
  BinaryOp(BinOp, Expr, Expr)           // 二項演算: op, lhs, rhs
  UnaryOp(UnaryOp, Expr)                // 単項演算: op, operand
  Call(String, Array[Expr])              // 関数呼び出し: name, args
  Assign(Expr, Expr)                    // 代入: lhs, rhs
} derive(Show, Eq)

/// 文
pub(all) enum Stmt {
  Return(Expr?)                        // return 文: 式（void 関数では None）
  VarDecl(String, String, Expr?)       // 変数宣言: 型名, 変数名, 初期値
  ExprStmt(Expr)                       // 式文
  Block(Array[Stmt])                   // ブロック: 文のリスト
  If(Expr, Stmt, Stmt?)               // if 文: 条件, then 節, else 節
  While(Expr, Stmt)                    // while 文: 条件, 本体
  For(Stmt?, Expr?, Expr?, Stmt)       // for 文: 初期化, 条件, 更新, 本体
} derive(Show, Eq)

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
