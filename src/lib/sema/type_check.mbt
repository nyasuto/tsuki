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

/// プログラム全体を型チェックする
pub fn TypeChecker::check_program(
  self : TypeChecker,
  program : @ast.Program
) -> Result[Unit, String] {
  // パス0: 構造体定義を先に登録（他の宣言で struct 型を使えるようにする）
  for tl in program.top_levels {
    match tl {
      StructDef(name, fields) =>
        match self.symbols.register_struct(name, fields) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
      FuncDef(_, _, _, _) => ()
      GlobalVarDecl(_, _, _) => ()
    }
  }
  // パス1: 全てのトップレベル宣言をシンボルテーブルに登録
  for tl in program.top_levels {
    match tl {
      FuncDef(ret_type_name, name, params, _body) => {
        let ret_type = match resolve_type_name(ret_type_name) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        let param_types : Array[@ast.CType] = []
        for p in params {
          let pt = match resolve_type_name(p.type_name) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          param_types.push(pt)
        }
        match self.symbols.add_symbol(name, Function(ret_type, param_types)) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
      }
      GlobalVarDecl(type_name, name, _init) => {
        let ty = match resolve_type_name(type_name) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        match self.symbols.add_symbol(name, Variable(ty)) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
      }
      StructDef(_, _) => () // パス0で処理済み
    }
  }
  // パス2: 各関数の本体を型チェック
  for tl in program.top_levels {
    match tl {
      FuncDef(ret_type_name, _name, params, body) => {
        let ret_type = match resolve_type_name(ret_type_name) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        self.current_return_type = Some(ret_type)
        // 関数スコープ
        self.symbols.enter_scope()
        for p in params {
          let pt = match resolve_type_name(p.type_name) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          match self.symbols.add_symbol(p.name, Variable(pt)) {
            Ok(_) => ()
            Err(e) => return Err(e)
          }
        }
        match self.check_stmt(body) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
        match self.symbols.leave_scope() {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
        self.current_return_type = None
      }
      GlobalVarDecl(type_name, _name, init) =>
        match init {
          Some(expr) => {
            let ty = match resolve_type_name(type_name) {
              Ok(t) => t
              Err(e) => return Err(e)
            }
            let expr_type = match self.infer_expr(expr) {
              Ok(t) => t
              Err(e) => return Err(e)
            }
            if not(is_assignable(ty, expr_type)) {
              return Err(
                "type mismatch in global variable initializer: expected " +
                ty.to_string() +
                ", got " +
                expr_type.to_string(),
              )
            }
          }
          None => ()
        }
      StructDef(_, _) => () // パス0で処理済み
    }
  }
  Ok(())
}

/// 文を型チェックする
fn TypeChecker::check_stmt(
  self : TypeChecker,
  stmt : @ast.Stmt
) -> Result[Unit, String] {
  match stmt {
    Return(expr_opt) =>
      match (self.current_return_type, expr_opt) {
        (Some(Void), None) => Ok(())
        (Some(Void), Some(_)) =>
          Err("void function should not return a value")
        (Some(expected), Some(expr)) => {
          let actual = match self.infer_expr(expr) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          if is_assignable(expected, actual) {
            Ok(())
          } else {
            Err(
              "return type mismatch: expected " +
              expected.to_string() +
              ", got " +
              actual.to_string(),
            )
          }
        }
        (Some(_), None) => Ok(()) // C では return; は非void関数でも許容（未定義動作だが）
        (None, _) => Err("return statement outside of function")
      }
    VarDecl(type_name, name, init) => {
      let ty = match resolve_type_name(type_name) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      match self.symbols.add_symbol(name, Variable(ty)) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      match init {
        Some(expr) => {
          let expr_type = match self.infer_expr(expr) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          if not(is_assignable(ty, expr_type)) {
            Err(
              "type mismatch in variable '" +
              name +
              "': expected " +
              ty.to_string() +
              ", got " +
              expr_type.to_string(),
            )
          } else {
            Ok(())
          }
        }
        None => Ok(())
      }
    }
    ExprStmt(expr) => {
      match self.infer_expr(expr) {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
    }
    Block(stmts) => {
      self.symbols.enter_scope()
      for s in stmts {
        match self.check_stmt(s) {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
      }
      match self.symbols.leave_scope() {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
    }
    If(cond, then_branch, else_branch) => {
      match self.infer_expr(cond) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      match self.check_stmt(then_branch) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      match else_branch {
        Some(eb) =>
          match self.check_stmt(eb) {
            Ok(_) => Ok(())
            Err(e) => Err(e)
          }
        None => Ok(())
      }
    }
    While(cond, body) => {
      match self.infer_expr(cond) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      self.check_stmt(body)
    }
    For(init, cond, update, body) => {
      // for のスコープ（init で宣言された変数のスコープ）
      self.symbols.enter_scope()
      match init {
        Some(s) =>
          match self.check_stmt(s) {
            Ok(_) => ()
            Err(e) => return Err(e)
          }
        None => ()
      }
      match cond {
        Some(e) =>
          match self.infer_expr(e) {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
        None => ()
      }
      match update {
        Some(e) =>
          match self.infer_expr(e) {
            Ok(_) => ()
            Err(err) => return Err(err)
          }
        None => ()
      }
      match self.check_stmt(body) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
      match self.symbols.leave_scope() {
        Ok(_) => Ok(())
        Err(e) => Err(e)
      }
    }
  }
}

/// 式の型を推論する
pub fn TypeChecker::infer_expr(
  self : TypeChecker,
  expr : @ast.Expr
) -> Result[@ast.CType, String] {
  match expr {
    IntLiteral(_) => Ok(@ast.CType::Int)
    CharLiteral(_) => Ok(@ast.CType::Char)
    StringLiteral(_) => Ok(@ast.CType::Ptr(@ast.CType::Char))
    Ident(name) =>
      match self.symbols.lookup(name) {
        Some(sym) =>
          match sym.kind {
            Variable(ty) => Ok(ty)
            Function(ret_ty, _) => Ok(ret_ty)
          }
        None => Err("undefined variable: '" + name + "'")
      }
    BinaryOp(op, lhs, rhs) => {
      let lhs_type = match self.infer_expr(lhs) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let rhs_type = match self.infer_expr(rhs) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      self.check_binary_op(op, lhs_type, rhs_type)
    }
    UnaryOp(op, operand) => {
      let operand_type = match self.infer_expr(operand) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      self.check_unary_op(op, operand_type)
    }
    Call(name, args) =>
      match self.symbols.lookup(name) {
        Some(sym) =>
          match sym.kind {
            Function(ret_type, param_types) => {
              if args.length() != param_types.length() {
                return Err(
                  "function '" +
                  name +
                  "' expects " +
                  param_types.length().to_string() +
                  " arguments, got " +
                  args.length().to_string(),
                )
              }
              for i = 0; i < args.length(); i = i + 1 {
                let arg_type = match self.infer_expr(args[i]) {
                  Ok(t) => t
                  Err(e) => return Err(e)
                }
                if not(is_assignable(param_types[i], arg_type)) {
                  return Err(
                    "argument " +
                    (i + 1).to_string() +
                    " of '" +
                    name +
                    "': expected " +
                    param_types[i].to_string() +
                    ", got " +
                    arg_type.to_string(),
                  )
                }
              }
              Ok(ret_type)
            }
            Variable(_) => Err("'" + name + "' is not a function")
          }
        None => Err("undefined function: '" + name + "'")
      }
    Assign(lhs, rhs) => {
      let lhs_type = match self.infer_expr(lhs) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let rhs_type = match self.infer_expr(rhs) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      if not(is_assignable(lhs_type, rhs_type)) {
        Err(
          "cannot assign " +
          rhs_type.to_string() +
          " to " +
          lhs_type.to_string(),
        )
      } else {
        Ok(lhs_type)
      }
    }
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
              lhs.to_string() +
              " and " +
              rhs.to_string(),
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
              lhs.to_string() +
              " and " +
              rhs.to_string(),
            )
          }
      }
    Mul | Div | Mod =>
      if is_integer_type(lhs) && is_integer_type(rhs) {
        Ok(@ast.CType::Int)
      } else {
        Err(
          "invalid operands to arithmetic operator: " +
          lhs.to_string() +
          " and " +
          rhs.to_string(),
        )
      }
    Eq | Ne | Lt | Gt | Le | Ge =>
      if is_assignable(lhs, rhs) || is_assignable(rhs, lhs) {
        Ok(@ast.CType::Int)
      } else {
        Err(
          "invalid comparison between " +
          lhs.to_string() +
          " and " +
          rhs.to_string(),
        )
      }
    LogAnd | LogOr => Ok(@ast.CType::Int)
    BitAnd | BitOr | BitXor | Shl | Shr =>
      if is_integer_type(lhs) && is_integer_type(rhs) {
        Ok(@ast.CType::Int)
      } else {
        Err(
          "invalid operands to bitwise operator: " +
          lhs.to_string() +
          " and " +
          rhs.to_string(),
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
        Err("invalid operand to unary '-': " + operand.to_string())
      }
    LogNot => Ok(@ast.CType::Int)
    BitNot =>
      if is_integer_type(operand) {
        Ok(@ast.CType::Int)
      } else {
        Err("invalid operand to '~': " + operand.to_string())
      }
    Deref =>
      match operand {
        Ptr(inner) => Ok(inner)
        _ =>
          Err(
            "cannot dereference non-pointer type: " + operand.to_string(),
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
              operand.to_string(),
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
              operand.to_string(),
            )
        }
      }
  }
}
