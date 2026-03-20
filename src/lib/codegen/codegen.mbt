/// Codegen: AST → Wasm 命令列の生成
/// 式のコード生成を担当する

/// Codegen エラー型
pub suberror CodegenError {
  CodegenError(String)
}

/// Wasm 命令のオペコード定数
let op_i32_const : Byte = b'\x41'
let op_i32_eqz : Byte = b'\x45'
let op_i32_eq : Byte = b'\x46'
let op_i32_ne : Byte = b'\x47'
let op_i32_lt_s : Byte = b'\x48'
let op_i32_gt_s : Byte = b'\x4A'
let op_i32_le_s : Byte = b'\x4C'
let op_i32_ge_s : Byte = b'\x4E'
let op_i32_add : Byte = b'\x6A'
let op_i32_sub : Byte = b'\x6B'
let op_i32_mul : Byte = b'\x6C'
let op_i32_div_s : Byte = b'\x6D'
let op_i32_rem_s : Byte = b'\x6F'
let op_i32_and : Byte = b'\x71'
let op_i32_or : Byte = b'\x72'
let op_i32_xor : Byte = b'\x73'
let op_i32_shl : Byte = b'\x74'
let op_i32_shr_s : Byte = b'\x75'

/// 二項演算子を対応する Wasm オペコードに変換する
fn binop_to_opcode(op : @ast.BinOp) -> Byte {
  match op {
    Add => op_i32_add
    Sub => op_i32_sub
    Mul => op_i32_mul
    Div => op_i32_div_s
    Mod => op_i32_rem_s
    Eq => op_i32_eq
    Ne => op_i32_ne
    Lt => op_i32_lt_s
    Gt => op_i32_gt_s
    Le => op_i32_le_s
    Ge => op_i32_ge_s
    BitAnd => op_i32_and
    BitOr => op_i32_or
    BitXor => op_i32_xor
    Shl => op_i32_shl
    Shr => op_i32_shr_s
    LogAnd => op_i32_and // 暫定: 短絡評価は Phase 3 で実装
    LogOr => op_i32_or   // 暫定: 短絡評価は Phase 3 で実装
  }
}

/// 式のコード生成: AST の Expr を Wasm 命令列（バイト列）に変換する
/// code 配列に命令バイトを追記する
pub fn emit_expr(expr : @ast.Expr, code : Array[Byte]) -> Unit raise CodegenError {
  match expr {
    IntLiteral(n) => {
      code.push(op_i32_const)
      let bytes = @wasm.encode_sleb128(n)
      for b in bytes {
        code.push(b)
      }
    }
    CharLiteral(c) => {
      code.push(op_i32_const)
      let bytes = @wasm.encode_sleb128(c.to_int())
      for b in bytes {
        code.push(b)
      }
    }
    BinaryOp(op, lhs, rhs) => {
      emit_expr(lhs, code)
      emit_expr(rhs, code)
      code.push(binop_to_opcode(op))
    }
    UnaryOp(Neg, operand) => {
      // -x → 0 - x
      code.push(op_i32_const)
      code.push(b'\x00')
      emit_expr(operand, code)
      code.push(op_i32_sub)
    }
    UnaryOp(LogNot, operand) => {
      // !x → x == 0
      emit_expr(operand, code)
      code.push(op_i32_eqz)
    }
    UnaryOp(BitNot, operand) => {
      // ~x → x ^ -1
      emit_expr(operand, code)
      code.push(op_i32_const)
      let bytes = @wasm.encode_sleb128(-1)
      for b in bytes {
        code.push(b)
      }
      code.push(op_i32_xor)
    }
    // 以下の式は後続タスクで実装する
    Ident(_) =>
      raise CodegenError("codegen: Ident は未実装（ローカル変数タスクで実装）")
    Call(_, _) =>
      raise CodegenError("codegen: Call は未実装（関数呼び出しタスクで実装）")
    Assign(_, _) =>
      raise CodegenError("codegen: Assign は未実装（変数代入タスクで実装）")
    StringLiteral(_) =>
      raise CodegenError("codegen: StringLiteral は未実装（Phase 5 で実装）")
    UnaryOp(Deref, _) =>
      raise CodegenError("codegen: Deref は未実装（Phase 4 で実装）")
    UnaryOp(AddrOf, _) =>
      raise CodegenError("codegen: AddrOf は未実装（Phase 4 で実装）")
  }
}
