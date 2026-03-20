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
