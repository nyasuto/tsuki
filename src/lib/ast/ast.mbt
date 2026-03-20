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

/// トップレベル定義
pub(all) enum TopLevel {
  FuncDef(String, String, Array[Param], Stmt)       // 関数定義: 戻り値型, 関数名, パラメータ, 本体(Block)
  GlobalVarDecl(String, String, Expr?)               // グローバル変数宣言: 型名, 変数名, 初期値
} derive(Show, Eq)

/// プログラム: トップレベル定義のリスト
pub(all) struct Program {
  top_levels : Array[TopLevel]
} derive(Show, Eq)
