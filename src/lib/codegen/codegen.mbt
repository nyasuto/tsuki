/// Codegen: AST → Wasm 命令列の生成
/// 式のコード生成を担当する

/// Codegen エラー型
pub suberror CodegenError {
  CodegenError(String)
}

/// Wasm 命令のオペコード定数
let op_local_get : Byte = b'\x20'
let op_local_set : Byte = b'\x21'
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
let op_call : Byte = b'\x10'

/// コード生成コンテキスト: 変数名 → Wasm local index のマッピングを管理する
pub struct CodegenContext {
  /// 変数名 → local index のマッピング
  locals : Map[String, Int]
  /// 次に割り当てる local index
  mut next_index : Int
  /// 関数名 → function index のマッピング
  functions : Map[String, Int]
}

/// 新しい CodegenContext を作成する
pub fn CodegenContext::new() -> CodegenContext {
  { locals: {}, next_index: 0, functions: {} }
}

/// 関数パラメータをローカル変数として登録する
/// パラメータは関数の先頭から順に local index 0, 1, 2, ... に割り当てられる
pub fn CodegenContext::from_params(
  params : Array[@ast.Param],
  functions~ : Map[String, Int] = {}
) -> CodegenContext {
  let ctx : CodegenContext = { locals: {}, next_index: 0, functions }
  for param in params {
    ctx.locals[param.name] = ctx.next_index
    ctx.next_index += 1
  }
  ctx
}

/// ローカル変数を登録し、割り当てられた local index を返す
pub fn CodegenContext::add_local(self : CodegenContext, name : String) -> Int {
  let index = self.next_index
  self.locals[name] = index
  self.next_index += 1
  index
}

/// 変数名から local index を取得する
pub fn CodegenContext::resolve(
  self : CodegenContext,
  name : String
) -> Int? {
  self.locals.get(name)
}

/// 関数名から function index を取得する
pub fn CodegenContext::resolve_function(
  self : CodegenContext,
  name : String
) -> Int? {
  self.functions.get(name)
}

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
/// ctx はローカル変数の解決に使用する
pub fn emit_expr(
  expr : @ast.Expr,
  code : Array[Byte],
  ctx : CodegenContext
) -> Unit raise CodegenError {
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
      emit_expr(lhs, code, ctx)
      emit_expr(rhs, code, ctx)
      code.push(binop_to_opcode(op))
    }
    UnaryOp(Neg, operand) => {
      // -x → 0 - x
      code.push(op_i32_const)
      code.push(b'\x00')
      emit_expr(operand, code, ctx)
      code.push(op_i32_sub)
    }
    UnaryOp(LogNot, operand) => {
      // !x → x == 0
      emit_expr(operand, code, ctx)
      code.push(op_i32_eqz)
    }
    UnaryOp(BitNot, operand) => {
      // ~x → x ^ -1
      emit_expr(operand, code, ctx)
      code.push(op_i32_const)
      let bytes = @wasm.encode_sleb128(-1)
      for b in bytes {
        code.push(b)
      }
      code.push(op_i32_xor)
    }
    Ident(name) =>
      match ctx.resolve(name) {
        Some(index) => {
          code.push(op_local_get)
          let bytes = @wasm.encode_uleb128(index)
          for b in bytes {
            code.push(b)
          }
        }
        None =>
          raise CodegenError(
            "codegen: 未定義の変数 '" + name + "'",
          )
      }
    Call(name, args) =>
      match ctx.resolve_function(name) {
        Some(func_index) => {
          // 引数を左から順にスタックに積む
          for arg in args {
            emit_expr(arg, code, ctx)
          }
          // call 命令: 関数インデックスを指定
          code.push(op_call)
          let bytes = @wasm.encode_uleb128(func_index)
          for b in bytes {
            code.push(b)
          }
        }
        None =>
          raise CodegenError(
            "codegen: 未定義の関数 '" + name + "'",
          )
      }
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

/// local.set 命令を生成するヘルパー関数
pub fn emit_local_set(
  index : Int,
  code : Array[Byte]
) -> Unit {
  code.push(op_local_set)
  let bytes = @wasm.encode_uleb128(index)
  for b in bytes {
    code.push(b)
  }
}
