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
let op_drop : Byte = b'\x1A'
let op_call : Byte = b'\x10'
let op_return : Byte = b'\x0F'
let op_local_tee : Byte = b'\x22'

/// 制御フロー命令のオペコード
let op_block : Byte = b'\x02'
let op_loop : Byte = b'\x03'
let op_if : Byte = b'\x04'
let op_else : Byte = b'\x05'
let op_end : Byte = b'\x0B'
let op_br : Byte = b'\x0C'
let op_br_if : Byte = b'\x0D'

/// ブロックタイプ: void（値を返さない）
let blocktype_void : Byte = b'\x40'

/// unreachable 命令: 到達不能コードをバリデータに通知する
let op_unreachable : Byte = b'\x00'

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
    Assign(Ident(name), value) =>
      match ctx.resolve(name) {
        Some(index) => {
          emit_expr(value, code, ctx)
          // local.tee: 値をスタックに残しつつ local に書き込む（C の代入は値を返す）
          code.push(op_local_tee)
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
    Assign(_, _) =>
      raise CodegenError("codegen: 左辺値が変数ではありません（ポインタ代入は Phase 4 で実装）")
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

/// 文のコード生成: AST の Stmt を Wasm 命令列（バイト列）に変換する
/// code 配列に命令バイトを追記する
pub fn emit_stmt(
  stmt : @ast.Stmt,
  code : Array[Byte],
  ctx : CodegenContext
) -> Unit raise CodegenError {
  match stmt {
    Return(Some(expr)) => {
      emit_expr(expr, code, ctx)
      code.push(op_return)
    }
    Return(None) => code.push(op_return)
    VarDecl(_type_name, name, init) => {
      let index = ctx.add_local(name)
      match init {
        Some(expr) => {
          emit_expr(expr, code, ctx)
          emit_local_set(index, code)
        }
        None => ()
      }
    }
    ExprStmt(expr) => {
      emit_expr(expr, code, ctx)
      // 式文の結果はスタックから捨てる
      code.push(op_drop)
    }
    Block(stmts) =>
      for stmt in stmts {
        emit_stmt(stmt, code, ctx)
      }
    If(cond, then_body, else_body) => {
      // 条件式をスタックに積む
      emit_expr(cond, code, ctx)
      // Wasm if ブロック（void 型: 値を返さない）
      code.push(op_if)
      code.push(blocktype_void)
      // then 節
      emit_stmt(then_body, code, ctx)
      // else 節（ある場合）
      match else_body {
        Some(else_stmt) => {
          code.push(op_else)
          emit_stmt(else_stmt, code, ctx)
        }
        None => ()
      }
      // end
      code.push(op_end)
    }
    While(cond, body) => {
      // block $break
      code.push(op_block)
      code.push(blocktype_void)
      // loop $continue
      code.push(op_loop)
      code.push(blocktype_void)
      // 条件式を評価
      emit_expr(cond, code, ctx)
      // 条件が偽（0）なら外側の block を抜ける
      code.push(op_i32_eqz)
      code.push(op_br_if)
      code.push(b'\x01') // depth 1: 外側の block へ
      // ループ本体
      emit_stmt(body, code, ctx)
      // loop の先頭に戻る
      code.push(op_br)
      code.push(b'\x00') // depth 0: 内側の loop へ
      // end (loop)
      code.push(op_end)
      // end (block)
      code.push(op_end)
    }
    For(init, cond, update, body) => {
      // for → while への AST レベル変換（desugar）
      // for (init; cond; update) body
      // → { init; while (cond) { body; update; } }
      let while_body = match update {
        Some(upd) => {
          // body の中身を展開して update を追加
          let stmts : Array[@ast.Stmt] = match body {
            Block(ss) => {
              let new_stmts = ss.copy()
              new_stmts.push(ExprStmt(upd))
              new_stmts
            }
            _ => [body, ExprStmt(upd)]
          }
          @ast.Stmt::Block(stmts)
        }
        None => body
      }
      let cond_expr = match cond {
        Some(c) => c
        None => @ast.Expr::IntLiteral(1) // 条件省略 → 無限ループ（常に真）
      }
      let while_stmt = @ast.Stmt::While(cond_expr, while_body)
      match init {
        Some(init_stmt) => {
          // init がある場合は Block で囲む
          emit_stmt(init_stmt, code, ctx)
          emit_stmt(while_stmt, code, ctx)
        }
        None => emit_stmt(while_stmt, code, ctx)
      }
    }
  }
}

/// C の型名を Wasm の ValType に変換する
/// int, char → I32、void → None（戻り値なし）
fn ctype_to_valtype(type_name : String) -> @wasm.ValType? {
  match type_name {
    "int" => Some(@wasm.I32)
    "char" => Some(@wasm.I32)
    "void" => None
    _ => Some(@wasm.I32) // 未知の型はとりあえず i32（Phase 4 で拡張）
  }
}

/// 関数定義から Wasm の FuncType（シグネチャ）を生成する
fn func_def_to_functype(
  return_type : String,
  params : Array[@ast.Param]
) -> @wasm.FuncType {
  let param_types : Array[@wasm.ValType] = Array::new(capacity=params.length())
  for _param in params {
    // Phase 2 ではすべてのパラメータ型は i32
    param_types.push(@wasm.I32)
  }
  let result_types : Array[@wasm.ValType] = match ctype_to_valtype(return_type) {
    Some(vt) => [vt]
    None => []
  }
  { params: param_types, results: result_types }
}

/// 単一の関数定義をコンパイルし、FuncBody を返す
/// params_count はパラメータの数（locals からは除外される）
fn compile_function(
  params : Array[@ast.Param],
  body : @ast.Stmt,
  functions : Map[String, Int]
) -> @wasm.FuncBody raise CodegenError {
  let ctx = CodegenContext::from_params(params, functions~)
  let code : Array[Byte] = []
  emit_stmt(body, code, ctx)
  // 関数末尾に unreachable を追加
  // 全パスが return で抜ける場合、関数 end 到達時のスタック型チェックを通すため
  code.push(op_unreachable)
  // パラメータ以外に追加されたローカル変数の数を計算
  let extra_locals = ctx.next_index - params.length()
  let locals : Array[@wasm.LocalDecl] = if extra_locals > 0 {
    [{ count: extra_locals, valtype: @wasm.I32 }]
  } else {
    []
  }
  { locals, code }
}

/// Program 全体をコンパイルして完全な Wasm バイナリ（Array[Byte]）を生成する
///
/// 処理の流れ:
/// 1. WASI proc_exit をインポート（function index 0）
/// 2. 全関数定義を走査して function index を割り当て（インポート数分オフセット）
/// 3. 各関数の FuncType（シグネチャ）を収集
/// 4. 各関数本体をコンパイルして FuncBody を生成
/// 5. _start ラッパー関数を生成（main を呼んで proc_exit に渡す）
/// 6. 全セクションを組み立てて .wasm バイナリを返す
pub fn compile_program(
  program : @ast.Program
) -> Array[Byte] raise CodegenError {
  // WASI インポート: proc_exit (i32) -> ()
  // インポートされた関数は function index の先頭に配置される
  let num_imports = 1
  let proc_exit_type_index = 0 // Type Section 内のインデックス
  let proc_exit_func_index = 0 // function index（インポート分）
  // 第1パス: 関数名 → function index のマッピングを構築
  // インポート関数の後にユーザー定義関数を配置する
  let functions : Map[String, Int] = {}
  let func_defs : Array[(@ast.TopLevel, Int)] = []
  let mut func_index = num_imports // インポート数分オフセット
  for top_level in program.top_levels {
    match top_level {
      FuncDef(_, name, _, _) => {
        functions[name] = func_index
        func_defs.push((top_level, func_index))
        func_index += 1
      }
      GlobalVarDecl(_, _, _) =>
        raise CodegenError("codegen: グローバル変数は未実装（Phase 4 で実装）")
    }
  }
  // 関数が1つもない場合はエラー
  if func_defs.is_empty() {
    raise CodegenError("codegen: プログラムに関数定義がありません")
  }
  // 第2パス: FuncType と FuncBody を収集
  // Type Section の構成: [proc_exit の型, ユーザー関数の型..., _start の型]
  let func_types : Array[@wasm.FuncType] = Array::new(
    capacity=func_defs.length() + 2,
  )
  // index 0: proc_exit の型 (i32) -> ()
  func_types.push({ params: [@wasm.I32], results: [] })
  // ユーザー定義関数の型
  let func_bodies : Array[@wasm.FuncBody] = Array::new(
    capacity=func_defs.length() + 1,
  )
  let type_indices : Array[Int] = Array::new(capacity=func_defs.length() + 1)
  for item in func_defs {
    let (top_level, _) = item
    match top_level {
      FuncDef(return_type, _, params, body) => {
        let ft = func_def_to_functype(return_type, params)
        func_types.push(ft)
        // type index = proc_exit の型(1つ) + ユーザー関数の順番
        type_indices.push(func_types.length() - 1)
        let fb = compile_function(params, body, functions)
        func_bodies.push(fb)
      }
      GlobalVarDecl(_, _, _) => () // 上のパスで既にエラーにしているため到達しない
    }
  }
  // _start ラッパー関数の生成: main() を呼んで proc_exit に渡す
  let start_func_index = func_index // _start の function index
  // _start の型: () -> ()
  let start_type_index = func_types.length()
  func_types.push({ params: [], results: [] })
  type_indices.push(start_type_index)
  // _start の本体: call $main; call $proc_exit
  let start_code : Array[Byte] = []
  match functions.get("main") {
    Some(main_index) => {
      // call $main
      start_code.push(op_call)
      let main_idx_bytes = @wasm.encode_uleb128(main_index)
      for b in main_idx_bytes {
        start_code.push(b)
      }
      // call $proc_exit (function index 0)
      start_code.push(op_call)
      let proc_exit_bytes = @wasm.encode_uleb128(proc_exit_func_index)
      for b in proc_exit_bytes {
        start_code.push(b)
      }
    }
    None =>
      raise CodegenError("codegen: main 関数が定義されていません")
  }
  func_bodies.push({ locals: [], code: start_code })
  // インポートの構築
  let imports : Array[@wasm.ImportEntry] = [
    {
      module_name: "wasi_snapshot_preview1",
      field_name: "proc_exit",
      desc: @wasm.ImportFunc(proc_exit_type_index),
    },
  ]
  // エクスポートの構築: _start 関数と memory をエクスポート
  let exports : Array[@wasm.ExportEntry] = Array::new(capacity=2)
  exports.push(
    { name: "_start", kind: @wasm.ExportFunc, index: start_func_index },
  )
  // memory もエクスポート
  exports.push(
    { name: "memory", kind: @wasm.ExportMem, index: 0 },
  )
  // Wasm モジュールの組み立て
  let result : Array[Byte] = Array::new(capacity=256)
  // ヘッダ
  let header = @wasm.encode_module_header()
  for b in header {
    result.push(b)
  }
  // Type Section
  let type_sec = @wasm.encode_type_section(func_types)
  for b in type_sec {
    result.push(b)
  }
  // Import Section
  let import_sec = @wasm.encode_import_section(imports)
  for b in import_sec {
    result.push(b)
  }
  // Function Section
  let func_sec = @wasm.encode_function_section(type_indices)
  for b in func_sec {
    result.push(b)
  }
  // Memory Section（1ページ = 64KiB）
  let mem_sec = @wasm.encode_memory_section([@wasm.LimitsMin(1)])
  for b in mem_sec {
    result.push(b)
  }
  // Export Section
  let export_sec = @wasm.encode_export_section(exports)
  for b in export_sec {
    result.push(b)
  }
  // Code Section
  let code_sec = @wasm.encode_code_section(func_bodies)
  for b in code_sec {
    result.push(b)
  }
  result
}
