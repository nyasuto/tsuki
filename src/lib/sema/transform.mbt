/// AST を型付き AST に変換する（プログラム全体）
/// 3パス処理: (0) 構造体登録 → (1) シンボル登録 → (2) 型付き AST 構築
pub fn TypeChecker::transform_program(
  self : TypeChecker,
  program : @ast.Program
) -> Result[@ast.TypedProgram, String] {
  // パス0: 構造体定義を先に登録
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
      StructDef(_, _) => ()
    }
  }
  // パス2: 各トップレベル定義を型付き AST に変換
  let typed_tops : Array[@ast.TypedTopLevel] = []
  for tl in program.top_levels {
    match tl {
      FuncDef(ret_type_name, name, params, body) => {
        let ret_type = match resolve_type_name(ret_type_name) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        self.current_return_type = Some(ret_type)
        self.symbols.enter_scope()
        let typed_params : Array[@ast.TypedParam] = []
        for p in params {
          let pt = match resolve_type_name(p.type_name) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          match self.symbols.add_symbol(p.name, Variable(pt)) {
            Ok(_) => ()
            Err(e) => return Err(e)
          }
          typed_params.push({ ty: pt, name: p.name })
        }
        let typed_body = match self.transform_stmt(body) {
          Ok(s) => s
          Err(e) => return Err(e)
        }
        match self.symbols.leave_scope() {
          Ok(_) => ()
          Err(e) => return Err(e)
        }
        self.current_return_type = None
        typed_tops.push(
          @ast.TypedTopLevel::FuncDef(ret_type, name, typed_params, typed_body),
        )
      }
      GlobalVarDecl(type_name, name, init) => {
        let ty = match resolve_type_name(type_name) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        match init {
          Some(expr) => {
            let typed_expr = match self.transform_expr(expr) {
              Ok(t) => t
              Err(e) => return Err(e)
            }
            if not(is_assignable(ty, typed_expr.ty)) {
              return Err(
                "type mismatch in global variable initializer: expected " +
                ty.to_string() +
                ", got " +
                typed_expr.ty.to_string(),
              )
            }
            typed_tops.push(@ast.TypedTopLevel::GlobalVarDecl(ty, name, Some(typed_expr)))
          }
          None =>
            typed_tops.push(@ast.TypedTopLevel::GlobalVarDecl(ty, name, None))
        }
      }
      StructDef(name, _fields) =>
        typed_tops.push(@ast.TypedTopLevel::StructDef(name))
    }
  }
  Ok({ top_levels: typed_tops })
}

/// 文を型付き文に変換する
pub fn TypeChecker::transform_stmt(
  self : TypeChecker,
  stmt : @ast.Stmt
) -> Result[@ast.TypedStmt, String] {
  match stmt {
    Return(expr_opt) =>
      match (self.current_return_type, expr_opt) {
        (Some(Void), None) => Ok(@ast.TypedStmt::Return(None))
        (Some(Void), Some(_)) =>
          Err("void function should not return a value")
        (Some(expected), Some(expr)) => {
          let typed = match self.transform_expr(expr) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          if is_assignable(expected, typed.ty) {
            Ok(@ast.TypedStmt::Return(Some(typed)))
          } else {
            Err(
              "return type mismatch: expected " +
              expected.to_string() +
              ", got " +
              typed.ty.to_string(),
            )
          }
        }
        (Some(_), None) => Ok(@ast.TypedStmt::Return(None))
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
          let typed = match self.transform_expr(expr) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          if not(is_assignable(ty, typed.ty)) {
            Err(
              "type mismatch in variable '" +
              name +
              "': expected " +
              ty.to_string() +
              ", got " +
              typed.ty.to_string(),
            )
          } else {
            Ok(@ast.TypedStmt::VarDecl(ty, name, Some(typed)))
          }
        }
        None => Ok(@ast.TypedStmt::VarDecl(ty, name, None))
      }
    }
    ExprStmt(expr) => {
      let typed = match self.transform_expr(expr) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      Ok(@ast.TypedStmt::ExprStmt(typed))
    }
    Block(stmts) => {
      self.symbols.enter_scope()
      let typed_stmts : Array[@ast.TypedStmt] = []
      for s in stmts {
        let typed = match self.transform_stmt(s) {
          Ok(t) => t
          Err(e) => return Err(e)
        }
        typed_stmts.push(typed)
      }
      match self.symbols.leave_scope() {
        Ok(_) => Ok(@ast.TypedStmt::Block(typed_stmts))
        Err(e) => Err(e)
      }
    }
    If(cond, then_branch, else_branch) => {
      let typed_cond = match self.transform_expr(cond) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let typed_then = match self.transform_stmt(then_branch) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      match else_branch {
        Some(eb) => {
          let typed_else = match self.transform_stmt(eb) {
            Ok(t) => t
            Err(e) => return Err(e)
          }
          Ok(@ast.TypedStmt::If(typed_cond, typed_then, Some(typed_else)))
        }
        None => Ok(@ast.TypedStmt::If(typed_cond, typed_then, None))
      }
    }
    While(cond, body) => {
      let typed_cond = match self.transform_expr(cond) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let typed_body = match self.transform_stmt(body) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      Ok(@ast.TypedStmt::While(typed_cond, typed_body))
    }
    For(init, cond, update, body) => {
      self.symbols.enter_scope()
      let typed_init : @ast.TypedStmt? = match init {
        Some(s) =>
          match self.transform_stmt(s) {
            Ok(t) => Some(t)
            Err(e) => return Err(e)
          }
        None => None
      }
      let typed_cond : @ast.TypedExpr? = match cond {
        Some(e) =>
          match self.transform_expr(e) {
            Ok(t) => Some(t)
            Err(e) => return Err(e)
          }
        None => None
      }
      let typed_update : @ast.TypedExpr? = match update {
        Some(e) =>
          match self.transform_expr(e) {
            Ok(t) => Some(t)
            Err(e) => return Err(e)
          }
        None => None
      }
      let typed_body = match self.transform_stmt(body) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      match self.symbols.leave_scope() {
        Ok(_) =>
          Ok(
            @ast.TypedStmt::For(
              typed_init, typed_cond, typed_update, typed_body,
            ),
          )
        Err(e) => Err(e)
      }
    }
  }
}

/// 式を型付き式に変換する（型推論 + 型付きノード構築）
pub fn TypeChecker::transform_expr(
  self : TypeChecker,
  expr : @ast.Expr
) -> Result[@ast.TypedExpr, String] {
  match expr {
    IntLiteral(n) =>
      Ok({ kind: @ast.TypedExprKind::IntLiteral(n), ty: @ast.CType::Int })
    CharLiteral(c) =>
      Ok({ kind: @ast.TypedExprKind::CharLiteral(c), ty: @ast.CType::Char })
    StringLiteral(s) =>
      Ok(
        {
          kind: @ast.TypedExprKind::StringLiteral(s),
          ty: @ast.CType::Ptr(@ast.CType::Char),
        },
      )
    Ident(name) =>
      match self.symbols.lookup(name) {
        Some(sym) =>
          match sym.kind {
            Variable(ty) =>
              Ok({ kind: @ast.TypedExprKind::Ident(name), ty })
            Function(ret_ty, _) =>
              Ok({ kind: @ast.TypedExprKind::Ident(name), ty: ret_ty })
          }
        None => Err("undefined variable: '" + name + "'")
      }
    BinaryOp(op, lhs, rhs) => {
      let typed_lhs = match self.transform_expr(lhs) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let typed_rhs = match self.transform_expr(rhs) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let result_ty = match self.check_binary_op(op, typed_lhs.ty, typed_rhs.ty) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      Ok(
        {
          kind: @ast.TypedExprKind::BinaryOp(op, typed_lhs, typed_rhs),
          ty: result_ty,
        },
      )
    }
    UnaryOp(op, operand) => {
      let typed_operand = match self.transform_expr(operand) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let result_ty = match self.check_unary_op(op, typed_operand.ty) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      Ok(
        {
          kind: @ast.TypedExprKind::UnaryOp(op, typed_operand),
          ty: result_ty,
        },
      )
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
              let typed_args : Array[@ast.TypedExpr] = []
              for i = 0; i < args.length(); i = i + 1 {
                let typed_arg = match self.transform_expr(args[i]) {
                  Ok(t) => t
                  Err(e) => return Err(e)
                }
                if not(is_assignable(param_types[i], typed_arg.ty)) {
                  return Err(
                    "argument " +
                    (i + 1).to_string() +
                    " of '" +
                    name +
                    "': expected " +
                    param_types[i].to_string() +
                    ", got " +
                    typed_arg.ty.to_string(),
                  )
                }
                typed_args.push(typed_arg)
              }
              Ok(
                {
                  kind: @ast.TypedExprKind::Call(name, typed_args),
                  ty: ret_type,
                },
              )
            }
            Variable(_) => Err("'" + name + "' is not a function")
          }
        None => Err("undefined function: '" + name + "'")
      }
    MemberAccess(base, field_name) => {
      let typed_base = match self.transform_expr(base) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      match typed_base.ty {
        Struct(sname) =>
          match self.symbols.lookup_struct(sname) {
            Some(info) => {
              // フィールドを検索
              let mut found : @ast.CType? = None
              for f in info.fields {
                if f.name == field_name {
                  found = Some(f.field_type)
                  break
                }
              }
              match found {
                Some(field_ty) =>
                  Ok(
                    {
                      kind: @ast.TypedExprKind::MemberAccess(typed_base, field_name),
                      ty: field_ty,
                    },
                  )
                None =>
                  Err(
                    "struct '" +
                    sname +
                    "' has no field named '" +
                    field_name +
                    "'",
                  )
              }
            }
            None => Err("undefined struct: '" + sname + "'")
          }
        other => Err("member access on non-struct type: " + other.to_string())
      }
    }
    SizeOf(type_name) => {
      let ty = match resolve_type_name(type_name) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let size = match self.symbols.size_of(ty) {
        Ok(s) => s
        Err(e) => return Err(e)
      }
      // sizeof はコンパイル時定数なので IntLiteral に畳み込む
      Ok({ kind: @ast.TypedExprKind::IntLiteral(size), ty: @ast.CType::Int })
    }
    Assign(lhs, rhs) => {
      let typed_lhs = match self.transform_expr(lhs) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      let typed_rhs = match self.transform_expr(rhs) {
        Ok(t) => t
        Err(e) => return Err(e)
      }
      if not(is_assignable(typed_lhs.ty, typed_rhs.ty)) {
        Err(
          "cannot assign " +
          typed_rhs.ty.to_string() +
          " to " +
          typed_lhs.ty.to_string(),
        )
      } else {
        Ok(
          {
            kind: @ast.TypedExprKind::Assign(typed_lhs, typed_rhs),
            ty: typed_lhs.ty,
          },
        )
      }
    }
  }
}
