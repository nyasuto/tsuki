/// 型チェッカー: シンボルテーブルを使って AST を走査し型の整合性を検証する
pub struct TypeChecker {
  symbols : SymbolTable
  /// 現在チェック中の関数の戻り値型（関数外では None）
  mut current_return_type : @ast.CType?
}

/// TypeChecker を作成する
pub fn TypeChecker::new() -> TypeChecker {
  { symbols: SymbolTable::new(), current_return_type: None }
}

/// 2つの型が代入互換かどうか判定する
/// - Int と Char は相互に代入可能（C の暗黙変換）
/// - 同じポインタ型どうしは互換
/// - Void への代入・Void からの代入は不可
pub fn is_assignable(target : @ast.CType, source : @ast.CType) -> Bool {
  match (target, source) {
    (Int, Int) => true
    (Char, Char) => true
    (Int, Char) => true
    (Char, Int) => true
    (Ptr(t), Ptr(s)) => t == s // ポインタの要素型は厳密一致
    (Ptr(_), Int) => true // C ではポインタに整数を代入可能
    (Int, Ptr(_)) => true // C ではポインタから整数への変換可能
    (Array(t, _), Ptr(s)) => is_assignable(t, s) // 配列はポインタとして扱える
    (Ptr(t), Array(s, _)) => is_assignable(t, s)
    (Void, Void) => true
    (Void, _) => false
    (_, Void) => false
    (Struct(a), Struct(b)) => a == b
    (Array(t, n1), Array(s, n2)) => n1 == n2 && is_assignable(t, s)
    _ => false
  }
}

/// 型が整数互換か（算術演算に使えるか）
fn is_integer_type(ty : @ast.CType) -> Bool {
  match ty {
    Int => true
    Char => true
    _ => false
  }
}

/// プログラム全体を型チェックする（transform_program への委譲）
pub fn TypeChecker::check_program(
  self : TypeChecker,
  program : @ast.Program
) -> Result[Unit, String] {
  match self.transform_program(program) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

/// 文を型チェックする（transform_stmt への委譲）
fn TypeChecker::check_stmt(
  self : TypeChecker,
  stmt : @ast.Stmt
) -> Result[Unit, String] {
  match self.transform_stmt(stmt) {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

/// 式の型を推論する（transform_expr への委譲）
pub fn TypeChecker::infer_expr(
  self : TypeChecker,
  expr : @ast.Expr
) -> Result[@ast.CType, String] {
  match self.transform_expr(expr) {
    Ok(typed) => Ok(typed.ty)
    Err(e) => Err(e)
  }
}

/// 二項演算の型チェック
fn TypeChecker::check_binary_op(
  self : TypeChecker,
  op : @ast.BinOp,
  lhs : @ast.CType,
  rhs : @ast.CType
) -> Result[@ast.CType, String] {
  let _ = self
  match op {
    Add =>
      match (lhs, rhs) {
        (Ptr(_), _) => Ok(lhs)
        (_, Ptr(_)) => Ok(rhs)
        _ =>
          if is_integer_type(lhs) && is_integer_type(rhs) {
            Ok(@ast.CType::Int)
          } else {
            Err(
              "invalid operands to '+': " +
              @ast.format_type(lhs) +
              " and " +
              @ast.format_type(rhs),
            )
          }
      }
    Sub =>
      match (lhs, rhs) {
        (Ptr(_), Ptr(_)) => Ok(@ast.CType::Int)
        (Ptr(_), _) => Ok(lhs)
        _ =>
          if is_integer_type(lhs) && is_integer_type(rhs) {
            Ok(@ast.CType::Int)
          } else {
            Err(
              "invalid operands to '-': " +
              @ast.format_type(lhs) +
              " and " +
              @ast.format_type(rhs),
            )
          }
      }
    Mul | Div | Mod =>
      if is_integer_type(lhs) && is_integer_type(rhs) {
        Ok(@ast.CType::Int)
      } else {
        Err(
          "invalid operands to arithmetic operator: " +
          @ast.format_type(lhs) +
          " and " +
          @ast.format_type(rhs),
        )
      }
    Eq | Ne | Lt | Gt | Le | Ge =>
      if is_assignable(lhs, rhs) || is_assignable(rhs, lhs) {
        Ok(@ast.CType::Int)
      } else {
        Err(
          "invalid comparison between " +
          @ast.format_type(lhs) +
          " and " +
          @ast.format_type(rhs),
        )
      }
    LogAnd | LogOr => Ok(@ast.CType::Int)
    BitAnd | BitOr | BitXor | Shl | Shr =>
      if is_integer_type(lhs) && is_integer_type(rhs) {
        Ok(@ast.CType::Int)
      } else {
        Err(
          "invalid operands to bitwise operator: " +
          @ast.format_type(lhs) +
          " and " +
          @ast.format_type(rhs),
        )
      }
  }
}

/// 単項演算の型チェック
fn TypeChecker::check_unary_op(
  self : TypeChecker,
  op : @ast.UnaryOp,
  operand : @ast.CType
) -> Result[@ast.CType, String] {
  let _ = self
  match op {
    Neg =>
      if is_integer_type(operand) {
        Ok(@ast.CType::Int)
      } else {
        Err("invalid operand to unary '-': " + @ast.format_type(operand))
      }
    LogNot => Ok(@ast.CType::Int)
    BitNot =>
      if is_integer_type(operand) {
        Ok(@ast.CType::Int)
      } else {
        Err("invalid operand to '~': " + @ast.format_type(operand))
      }
    Deref =>
      match operand {
        Ptr(inner) => Ok(inner)
        _ =>
          Err(
            "cannot dereference non-pointer type: " + @ast.format_type(operand),
          )
      }
    AddrOf => Ok(@ast.CType::Ptr(operand))
    PreInc | PreDec =>
      if is_integer_type(operand) {
        Ok(operand)
      } else {
        match operand {
          Ptr(_) => Ok(operand)
          _ =>
            Err(
              "invalid operand to increment/decrement: " +
              @ast.format_type(operand),
            )
        }
      }
    PostInc | PostDec =>
      if is_integer_type(operand) {
        Ok(operand)
      } else {
        match operand {
          Ptr(_) => Ok(operand)
          _ =>
            Err(
              "invalid operand to increment/decrement: " +
              @ast.format_type(operand),
            )
        }
      }
  }
}
