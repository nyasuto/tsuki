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

/// ブロックタイプ: i32（i32 値を返す）
let blocktype_i32 : Byte = b'\x7F'

/// unreachable 命令: 到達不能コードをバリデータに通知する
let op_unreachable : Byte = b'\x00'

/// グローバル変数命令のオペコード
let op_global_get : Byte = b'\x23'
let op_global_set : Byte = b'\x24'

/// メモリ命令のオペコード
let op_i32_load : Byte = b'\x28'
let op_i32_store : Byte = b'\x36'

/// スタックポインタのグローバルインデックス
let sp_global_index : Int = 0

/// メモリサイズ（1ページ = 64KiB = 65536バイト）
let memory_page_size : Int = 65536

/// コード生成コンテキスト: 変数名 → Wasm local index のマッピングを管理する
pub struct CodegenContext {
  /// 変数名 → local index のマッピング
  locals : Map[String, Int]
  /// 次に割り当てる local index
  mut next_index : Int
  /// 関数名 → function index のマッピング
  functions : Map[String, Int]
  /// 関数のスタックフレームサイズ（バイト数）
  /// アドレスを取る変数（&x）がスタック上に配置されるとき、このサイズが増加する
  pub mut frame_size : Int
  /// スタック配置変数: 変数名 → SP からのオフセット
  /// アドレスを取る変数（&x）や構造体変数がスタック上に配置される
  stack_vars : Map[String, Int]
  /// アドレスが取られる変数名のセット（事前スキャンで構築）
  addr_taken : Map[String, Bool]
  /// 一時変数の Wasm local index（スタック変数の代入時に使用）
  mut temp_local : Int?
  /// 変数名 → 解決済み型のマッピング（ポインタ演算のスケーリングに使用）
  var_types : Map[String, @ast.CType]
  /// 構造体定義のレジストリ（名前 → レイアウト情報）
  struct_defs : Map[String, @sema.StructInfo]
}

/// 新しい CodegenContext を作成する
pub fn CodegenContext::new(
  struct_defs~ : Map[String, @sema.StructInfo] = {}
) -> CodegenContext {
  {
    locals: {},
    next_index: 0,
    functions: {},
    frame_size: 0,
    stack_vars: {},
    addr_taken: {},
    temp_local: None,
    var_types: {},
    struct_defs,
  }
}

/// 関数パラメータをローカル変数として登録する
/// パラメータは関数の先頭から順に local index 0, 1, 2, ... に割り当てられる
pub fn CodegenContext::from_params(
  params : Array[@ast.Param],
  functions~ : Map[String, Int] = {},
  addr_taken~ : Map[String, Bool] = {},
  struct_defs~ : Map[String, @sema.StructInfo] = {}
) -> CodegenContext {
  let ctx : CodegenContext = {
    locals: {},
    next_index: 0,
    functions,
    frame_size: 0,
    stack_vars: {},
    addr_taken,
    temp_local: None,
    var_types: {},
    struct_defs,
  }
  for param in params {
    ctx.locals[param.name] = ctx.next_index
    ctx.next_index += 1
    // パラメータの型を解決して記録する（ポインタ演算のスケーリングに必要）
    match @sema.resolve_type_name(param.type_name) {
      Ok(ty) => ctx.var_types[param.name] = ty
      Err(_) => ()
    }
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

/// 一時変数の Wasm local index を取得する（遅延割り当て）
/// スタック変数の代入式で値を保持するために使用する
pub fn CodegenContext::get_temp_local(self : CodegenContext) -> Int {
  match self.temp_local {
    Some(idx) => idx
    None => {
      let idx = self.next_index
      self.next_index += 1
      self.temp_local = Some(idx)
      idx
    }
  }
}

/// 変数がスタック配置かどうかを判定する
pub fn CodegenContext::is_stack_var(
  self : CodegenContext,
  name : String
) -> Bool {
  self.stack_vars.contains(name)
}

/// スタック変数を登録する: スタックフレーム上に 4 バイト確保し、オフセットを記録する
pub fn CodegenContext::add_stack_var(self : CodegenContext, name : String) -> Int {
  let offset = self.allocate_on_stack(4)
  self.stack_vars[name] = offset
  offset
}

/// 構造体変数をスタックに配置する: 構造体のサイズ分の領域を確保し、オフセットを記録する
pub fn CodegenContext::add_struct_stack_var(
  self : CodegenContext,
  name : String,
  struct_size : Int
) -> Int {
  let offset = self.allocate_on_stack(struct_size)
  self.stack_vars[name] = offset
  offset
}

/// スタックフレーム上に指定サイズの領域を確保し、SP からのオフセットを返す
/// 4 バイトアラインメントを適用する
pub fn CodegenContext::allocate_on_stack(self : CodegenContext, size : Int) -> Int {
  // 4 バイト境界にアラインメント
  let aligned = (size + 3) / 4 * 4
  let offset = self.frame_size
  self.frame_size += aligned
  offset
}

/// 関数プロローグを生成する: SP -= frame_size
/// スタックは上位アドレスから下位に向かって成長する
/// frame_size が 0 の場合は何も生成しない
pub fn emit_prologue(frame_size : Int, code : Array[Byte]) -> Unit {
  if frame_size > 0 {
    // global.get $sp
    code.push(op_global_get)
    let sp_bytes = @wasm.encode_uleb128(sp_global_index)
    for b in sp_bytes {
      code.push(b)
    }
    // i32.const frame_size
    code.push(op_i32_const)
    let size_bytes = @wasm.encode_sleb128(frame_size)
    for b in size_bytes {
      code.push(b)
    }
    // i32.sub
    code.push(op_i32_sub)
    // global.set $sp
    code.push(op_global_set)
    let sp_bytes2 = @wasm.encode_uleb128(sp_global_index)
    for b in sp_bytes2 {
      code.push(b)
    }
  }
}

/// 関数エピローグを生成する: SP += frame_size
/// frame_size が 0 の場合は何も生成しない
pub fn emit_epilogue(frame_size : Int, code : Array[Byte]) -> Unit {
  if frame_size > 0 {
    // global.get $sp
    code.push(op_global_get)
    let sp_bytes = @wasm.encode_uleb128(sp_global_index)
    for b in sp_bytes {
      code.push(b)
    }
    // i32.const frame_size
    code.push(op_i32_const)
    let size_bytes = @wasm.encode_sleb128(frame_size)
    for b in size_bytes {
      code.push(b)
    }
    // i32.add
    code.push(op_i32_add)
    // global.set $sp
    code.push(op_global_set)
    let sp_bytes2 = @wasm.encode_uleb128(sp_global_index)
    for b in sp_bytes2 {
      code.push(b)
    }
  }
}

/// スタック変数のアドレスをスタックに積む: global.get $sp + i32.const offset + i32.add
fn emit_stack_addr(offset : Int, code : Array[Byte]) -> Unit {
  // global.get $sp
  code.push(op_global_get)
  for b in @wasm.encode_uleb128(sp_global_index) {
    code.push(b)
  }
  // i32.const offset
  code.push(op_i32_const)
  for b in @wasm.encode_sleb128(offset) {
    code.push(b)
  }
  // i32.add
  code.push(op_i32_add)
}

/// スタック変数の値をロードする: アドレスを計算して i32.load
fn emit_stack_load(offset : Int, code : Array[Byte]) -> Unit {
  emit_stack_addr(offset, code)
  // i32.load align=2 offset=0
  code.push(op_i32_load)
  code.push(b'\x02') // alignment: 2^2 = 4 bytes
  code.push(b'\x00') // memory offset: 0
}

/// i32.store 命令を生成する（アドレスと値がスタック上にあることが前提）
fn emit_i32_store(code : Array[Byte]) -> Unit {
  code.push(op_i32_store)
  code.push(b'\x02') // alignment: 2^2 = 4 bytes
  code.push(b'\x00') // memory offset: 0
}

/// 関数本体の AST を走査し、アドレスが取られる変数名を収集する
/// &x の形で参照される変数のセットを返す
pub fn collect_addr_taken_vars(stmt : @ast.Stmt) -> Map[String, Bool] {
  let vars : Map[String, Bool] = {}
  collect_addr_taken_in_stmt(stmt, vars)
  vars
}

/// 式の中からアドレスが取られる変数を収集する
fn collect_addr_taken_in_expr(
  expr : @ast.Expr,
  vars : Map[String, Bool]
) -> Unit {
  match expr {
    UnaryOp(AddrOf, Ident(name)) => vars[name] = true
    UnaryOp(_, e) => collect_addr_taken_in_expr(e, vars)
    BinaryOp(_, l, r) => {
      collect_addr_taken_in_expr(l, vars)
      collect_addr_taken_in_expr(r, vars)
    }
    Call(_, args) =>
      for a in args {
        collect_addr_taken_in_expr(a, vars)
      }
    Assign(l, r) => {
      collect_addr_taken_in_expr(l, vars)
      collect_addr_taken_in_expr(r, vars)
    }
    MemberAccess(base, _) => collect_addr_taken_in_expr(base, vars)
    SizeOf(_) => ()
    IntLiteral(_) => ()
    CharLiteral(_) => ()
    StringLiteral(_) => ()
    Ident(_) => ()
  }
}

/// 文の中からアドレスが取られる変数を収集する
fn collect_addr_taken_in_stmt(
  stmt : @ast.Stmt,
  vars : Map[String, Bool]
) -> Unit {
  match stmt {
    Return(Some(e)) => collect_addr_taken_in_expr(e, vars)
    Return(None) => ()
    VarDecl(_, _, Some(e)) => collect_addr_taken_in_expr(e, vars)
    VarDecl(_, _, None) => ()
    ExprStmt(e) => collect_addr_taken_in_expr(e, vars)
    Block(stmts) =>
      for s in stmts {
        collect_addr_taken_in_stmt(s, vars)
      }
    If(c, t, Some(e)) => {
      collect_addr_taken_in_expr(c, vars)
      collect_addr_taken_in_stmt(t, vars)
      collect_addr_taken_in_stmt(e, vars)
    }
    If(c, t, None) => {
      collect_addr_taken_in_expr(c, vars)
      collect_addr_taken_in_stmt(t, vars)
    }
    While(c, b) => {
      collect_addr_taken_in_expr(c, vars)
      collect_addr_taken_in_stmt(b, vars)
    }
    For(init, cond, upd, body) => {
      match init {
        Some(s) => collect_addr_taken_in_stmt(s, vars)
        None => ()
      }
      match cond {
        Some(e) => collect_addr_taken_in_expr(e, vars)
        None => ()
      }
      match upd {
        Some(e) => collect_addr_taken_in_expr(e, vars)
        None => ()
      }
      collect_addr_taken_in_stmt(body, vars)
    }
  }
}

/// 式から構造体名を推定する（メンバアクセスのフィールドオフセット解決用）
fn infer_struct_name(
  expr : @ast.Expr,
  ctx : CodegenContext
) -> String? {
  match expr {
    Ident(name) =>
      match ctx.var_types.get(name) {
        Some(Struct(sname)) => Some(sname)
        _ => None
      }
    MemberAccess(base, field_name) =>
      // ネストしたメンバアクセス: base のフィールド型を辿る
      match infer_struct_name(base, ctx) {
        Some(sname) =>
          match ctx.struct_defs.get(sname) {
            Some(info) => {
              let mut result : String? = None
              for f in info.fields {
                if f.name == field_name {
                  match f.field_type {
                    Struct(inner_sname) => result = Some(inner_sname)
                    _ => ()
                  }
                  break
                }
              }
              result
            }
            None => None
          }
        None => None
      }
    _ => None
  }
}

/// メンバアクセスのアドレスを生成する: ベースアドレス + フィールドオフセット
fn emit_member_addr(
  base : @ast.Expr,
  field_name : String,
  code : Array[Byte],
  ctx : CodegenContext
) -> Unit raise CodegenError {
  // ベースのアドレスを取得（構造体の Ident はアドレスを返す）
  emit_expr(base, code, ctx)
  // 構造体名を推定してフィールドオフセットを取得
  let sname = match infer_struct_name(base, ctx) {
    Some(s) => s
    None =>
      raise CodegenError("codegen: メンバアクセスのベースが構造体ではありません")
  }
  let info = match ctx.struct_defs.get(sname) {
    Some(i) => i
    None => raise CodegenError("codegen: 未定義の構造体 '\{sname}'")
  }
  let mut field_offset = -1
  for f in info.fields {
    if f.name == field_name {
      field_offset = f.offset
      break
    }
  }
  if field_offset < 0 {
    raise CodegenError(
      "codegen: 構造体 '\{sname}' にフィールド '\{field_name}' がありません",
    )
  }
  // i32.const field_offset + i32.add
  if field_offset > 0 {
    code.push(op_i32_const)
    for b in @wasm.encode_sleb128(field_offset) {
      code.push(b)
    }
    code.push(op_i32_add)
  }
}

/// 型のサイズをバイト単位で返す（ポインタ演算のスケーリング用）
fn size_of_ctype(
  ty : @ast.CType,
  struct_defs~ : Map[String, @sema.StructInfo] = {}
) -> Int {
  match ty {
    Int => 4
    Char => 1
    Void => 0
    Ptr(_) => 4
    Struct(name) =>
      match struct_defs.get(name) {
        Some(info) => info.total_size
        None => 4 // フォールバック: 未登録構造体は 4 バイト
      }
    Array(elem, count) => size_of_ctype(elem, struct_defs~) * count
  }
}

/// 式の型をコンテキストから推論する（ポインタ演算の検出用）
/// 完全な型推論ではなく、ポインタ型かどうかを判定するのに十分なレベル
fn infer_expr_type(
  expr : @ast.Expr,
  ctx : CodegenContext
) -> @ast.CType? {
  match expr {
    IntLiteral(_) => Some(@ast.CType::Int)
    CharLiteral(_) => Some(@ast.CType::Char)
    StringLiteral(_) => Some(@ast.CType::Ptr(@ast.CType::Char))
    Ident(name) => ctx.var_types.get(name)
    UnaryOp(AddrOf, Ident(name)) =>
      match ctx.var_types.get(name) {
        Some(ty) => Some(@ast.CType::Ptr(ty))
        None => None
      }
    UnaryOp(Deref, e) =>
      match infer_expr_type(e, ctx) {
        Some(Ptr(inner)) => Some(inner)
        Some(Int) => None
        Some(Char) => None
        Some(Void) => None
        Some(Struct(_)) => None
        Some(Array(_, _)) => None
        None => None
      }
    UnaryOp(AddrOf, _) => None
    UnaryOp(Neg, _) => Some(@ast.CType::Int)
    UnaryOp(LogNot, _) => Some(@ast.CType::Int)
    UnaryOp(BitNot, _) => Some(@ast.CType::Int)
    UnaryOp(PreInc, e) => infer_expr_type(e, ctx)
    UnaryOp(PreDec, e) => infer_expr_type(e, ctx)
    UnaryOp(PostInc, e) => infer_expr_type(e, ctx)
    UnaryOp(PostDec, e) => infer_expr_type(e, ctx)
    BinaryOp(Add, lhs, rhs) => {
      let lty = infer_expr_type(lhs, ctx)
      let rty = infer_expr_type(rhs, ctx)
      match (lty, rty) {
        (Some(Ptr(_)) as p, _) => p
        (_, Some(Ptr(_)) as p) => p
        _ => Some(@ast.CType::Int)
      }
    }
    BinaryOp(Sub, lhs, rhs) => {
      let lty = infer_expr_type(lhs, ctx)
      let rty = infer_expr_type(rhs, ctx)
      match (lty, rty) {
        (Some(Ptr(_)), Some(Ptr(_))) => Some(@ast.CType::Int)
        (Some(Ptr(_)) as p, _) => p
        _ => Some(@ast.CType::Int)
      }
    }
    BinaryOp(_, _, _) => Some(@ast.CType::Int)
    Call(_, _) => None
    Assign(_, _) => None
    SizeOf(_) => Some(@ast.CType::Int)
    MemberAccess(base, field_name) =>
      match infer_struct_name(base, ctx) {
        Some(sname) =>
          match ctx.struct_defs.get(sname) {
            Some(info) => {
              let mut result : @ast.CType? = None
              for f in info.fields {
                if f.name == field_name {
                  result = Some(f.field_type)
                  break
                }
              }
              result
            }
            None => None
          }
        None => None
      }
  }
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
    // LogAnd, LogOr は emit_expr で短絡評価として特別に処理する
    LogAnd => abort("unreachable: LogAnd は emit_expr で処理")
    LogOr => abort("unreachable: LogOr は emit_expr で処理")
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
    BinaryOp(LogAnd, lhs, rhs) => {
      // 短絡評価: && → if(lhs, rhs, 0)
      // lhs が真なら rhs を評価、偽なら 0
      emit_expr(lhs, code, ctx)
      code.push(op_if)
      code.push(blocktype_i32)
      emit_expr(rhs, code, ctx)
      code.push(op_else)
      code.push(op_i32_const)
      code.push(b'\x00') // 0
      code.push(op_end)
    }
    BinaryOp(LogOr, lhs, rhs) => {
      // 短絡評価: || → if(lhs, 1, rhs)
      // lhs が真なら 1、偽なら rhs を評価
      emit_expr(lhs, code, ctx)
      code.push(op_if)
      code.push(blocktype_i32)
      code.push(op_i32_const)
      code.push(b'\x01') // 1
      code.push(op_else)
      emit_expr(rhs, code, ctx)
      code.push(op_end)
    }
    BinaryOp(Add, lhs, rhs) => {
      // ポインタ演算チェック: ptr + n → ptr + n * sizeof(*ptr)
      let lty = infer_expr_type(lhs, ctx)
      let rty = infer_expr_type(rhs, ctx)
      match (lty, rty) {
        (Some(Ptr(elem)), _) => {
          // ptr + n: ポインタ側を評価し、整数側を sizeof でスケーリング
          emit_expr(lhs, code, ctx)
          emit_expr(rhs, code, ctx)
          let sz = size_of_ctype(elem, struct_defs=ctx.struct_defs)
          if sz != 1 {
            code.push(op_i32_const)
            for b in @wasm.encode_sleb128(sz) {
              code.push(b)
            }
            code.push(op_i32_mul)
          }
          code.push(op_i32_add)
        }
        (_, Some(Ptr(elem))) => {
          // n + ptr: 整数側を sizeof でスケーリングしてからポインタ側を加算
          emit_expr(lhs, code, ctx)
          let sz = size_of_ctype(elem, struct_defs=ctx.struct_defs)
          if sz != 1 {
            code.push(op_i32_const)
            for b in @wasm.encode_sleb128(sz) {
              code.push(b)
            }
            code.push(op_i32_mul)
          }
          emit_expr(rhs, code, ctx)
          code.push(op_i32_add)
        }
        _ => {
          // 通常の整数加算
          emit_expr(lhs, code, ctx)
          emit_expr(rhs, code, ctx)
          code.push(op_i32_add)
        }
      }
    }
    BinaryOp(Sub, lhs, rhs) => {
      // ポインタ演算チェック
      let lty = infer_expr_type(lhs, ctx)
      let rty = infer_expr_type(rhs, ctx)
      match (lty, rty) {
        (Some(Ptr(elem)), Some(Ptr(_))) => {
          // ptr - ptr → (ptr1 - ptr2) / sizeof(elem)：要素数の差を返す
          emit_expr(lhs, code, ctx)
          emit_expr(rhs, code, ctx)
          code.push(op_i32_sub)
          let sz = size_of_ctype(elem, struct_defs=ctx.struct_defs)
          if sz != 1 {
            code.push(op_i32_const)
            for b in @wasm.encode_sleb128(sz) {
              code.push(b)
            }
            code.push(op_i32_div_s)
          }
        }
        (Some(Ptr(elem)), _) => {
          // ptr - n → ptr - n * sizeof(elem)
          emit_expr(lhs, code, ctx)
          emit_expr(rhs, code, ctx)
          let sz = size_of_ctype(elem, struct_defs=ctx.struct_defs)
          if sz != 1 {
            code.push(op_i32_const)
            for b in @wasm.encode_sleb128(sz) {
              code.push(b)
            }
            code.push(op_i32_mul)
          }
          code.push(op_i32_sub)
        }
        _ => {
          // 通常の整数減算
          emit_expr(lhs, code, ctx)
          emit_expr(rhs, code, ctx)
          code.push(op_i32_sub)
        }
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
      match ctx.stack_vars.get(name) {
        Some(offset) =>
          // スタック配置変数
          match ctx.var_types.get(name) {
            Some(Struct(_)) =>
              // 構造体変数: アドレスを返す（メンバアクセスやポインタ渡しで使用）
              emit_stack_addr(offset, code)
            _ =>
              // スカラー変数: メモリからロード
              emit_stack_load(offset, code)
          }
        None =>
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
      match ctx.stack_vars.get(name) {
        Some(offset) => {
          // スタック配置変数への代入: [addr, value] → i32.store
          // C の代入は値を返すので、temp local で値を保持する
          emit_stack_addr(offset, code) // [addr]
          emit_expr(value, code, ctx) // [addr, value]
          let temp = ctx.get_temp_local()
          code.push(op_local_tee) // [addr, value] (value saved to temp)
          let temp_bytes = @wasm.encode_uleb128(temp)
          for b in temp_bytes {
            code.push(b)
          }
          emit_i32_store(code) // []
          // 値を式の結果として残す
          code.push(op_local_get)
          let temp_bytes2 = @wasm.encode_uleb128(temp)
          for b in temp_bytes2 {
            code.push(b)
          }
        }
        None =>
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
      }
    Assign(MemberAccess(base, field_name), value) => {
      // s.field = value: ベースアドレス + フィールドオフセットに書き込む
      // C の代入は値を返すので、temp local で値を保持する
      emit_member_addr(base, field_name, code, ctx) // [addr]
      emit_expr(value, code, ctx) // [addr, value]
      let temp = ctx.get_temp_local()
      code.push(op_local_tee) // [addr, value] (value saved to temp)
      let temp_bytes = @wasm.encode_uleb128(temp)
      for b in temp_bytes {
        code.push(b)
      }
      emit_i32_store(code) // []
      // 値を式の結果として残す
      code.push(op_local_get)
      let temp_bytes2 = @wasm.encode_uleb128(temp)
      for b in temp_bytes2 {
        code.push(b)
      }
    }
    Assign(UnaryOp(Deref, addr_expr), value) => {
      // *p = value: アドレスを評価し、値を評価し、i32.store で書き込む
      // C の代入は値を返すので、temp local で値を保持する
      emit_expr(addr_expr, code, ctx) // [addr]
      emit_expr(value, code, ctx) // [addr, value]
      let temp = ctx.get_temp_local()
      code.push(op_local_tee) // [addr, value] (value saved to temp)
      let temp_bytes = @wasm.encode_uleb128(temp)
      for b in temp_bytes {
        code.push(b)
      }
      emit_i32_store(code) // []
      // 値を式の結果として残す
      code.push(op_local_get)
      let temp_bytes2 = @wasm.encode_uleb128(temp)
      for b in temp_bytes2 {
        code.push(b)
      }
    }
    Assign(_, _) =>
      raise CodegenError("codegen: 左辺値が変数ではありません")
    StringLiteral(_) =>
      raise CodegenError("codegen: StringLiteral は未実装（Phase 5 で実装）")
    UnaryOp(PreInc, Ident(name)) =>
      // ++x: x = x + 1; 新しい値を返す
      match ctx.stack_vars.get(name) {
        Some(offset) => {
          // スタック変数: load, +1, store, result
          let temp = ctx.get_temp_local()
          emit_stack_load(offset, code) // [old_value]
          code.push(op_i32_const)
          code.push(b'\x01')
          code.push(op_i32_add) // [new_value]
          emit_local_set(temp, code) // [] (new saved to temp)
          emit_stack_addr(offset, code) // [addr]
          code.push(op_local_get) // [addr, new_value]
          for b in @wasm.encode_uleb128(temp) {
            code.push(b)
          }
          emit_i32_store(code) // []
          code.push(op_local_get) // [new_value]
          for b in @wasm.encode_uleb128(temp) {
            code.push(b)
          }
        }
        None =>
          match ctx.resolve(name) {
            Some(index) => {
              code.push(op_local_get)
              let bytes = @wasm.encode_uleb128(index)
              for b in bytes {
                code.push(b)
              }
              code.push(op_i32_const)
              code.push(b'\x01')
              code.push(op_i32_add)
              code.push(op_local_tee)
              let bytes2 = @wasm.encode_uleb128(index)
              for b in bytes2 {
                code.push(b)
              }
            }
            None =>
              raise CodegenError(
                "codegen: 未定義の変数 '" + name + "'",
              )
          }
      }
    UnaryOp(PreDec, Ident(name)) =>
      // --x: x = x - 1; 新しい値を返す
      match ctx.stack_vars.get(name) {
        Some(offset) => {
          let temp = ctx.get_temp_local()
          emit_stack_load(offset, code)
          code.push(op_i32_const)
          code.push(b'\x01')
          code.push(op_i32_sub)
          emit_local_set(temp, code)
          emit_stack_addr(offset, code)
          code.push(op_local_get)
          for b in @wasm.encode_uleb128(temp) {
            code.push(b)
          }
          emit_i32_store(code)
          code.push(op_local_get)
          for b in @wasm.encode_uleb128(temp) {
            code.push(b)
          }
        }
        None =>
          match ctx.resolve(name) {
            Some(index) => {
              code.push(op_local_get)
              let bytes = @wasm.encode_uleb128(index)
              for b in bytes {
                code.push(b)
              }
              code.push(op_i32_const)
              code.push(b'\x01')
              code.push(op_i32_sub)
              code.push(op_local_tee)
              let bytes2 = @wasm.encode_uleb128(index)
              for b in bytes2 {
                code.push(b)
              }
            }
            None =>
              raise CodegenError(
                "codegen: 未定義の変数 '" + name + "'",
              )
          }
      }
    UnaryOp(PostInc, Ident(name)) =>
      // x++: 元の値を返し、x = x + 1 にする
      match ctx.stack_vars.get(name) {
        Some(offset) => {
          // スタック変数: old_value を返し、new_value を store
          emit_stack_load(offset, code) // [old_value] — 返り値
          emit_stack_addr(offset, code) // [old_value, addr]
          emit_stack_load(offset, code) // [old_value, addr, old_value2]
          code.push(op_i32_const)
          code.push(b'\x01')
          code.push(op_i32_add) // [old_value, addr, new_value]
          emit_i32_store(code) // [old_value]
        }
        None =>
          match ctx.resolve(name) {
            Some(index) => {
              // 元の値をスタックに積む（返り値）
              code.push(op_local_get)
              let bytes = @wasm.encode_uleb128(index)
              for b in bytes {
                code.push(b)
              }
              // x + 1 を計算して local に書き戻す
              code.push(op_local_get)
              let bytes2 = @wasm.encode_uleb128(index)
              for b in bytes2 {
                code.push(b)
              }
              code.push(op_i32_const)
              code.push(b'\x01')
              code.push(op_i32_add)
              emit_local_set(index, code)
            }
            None =>
              raise CodegenError(
                "codegen: 未定義の変数 '" + name + "'",
              )
          }
      }
    UnaryOp(PostDec, Ident(name)) =>
      // x--: 元の値を返し、x = x - 1 にする
      match ctx.stack_vars.get(name) {
        Some(offset) => {
          emit_stack_load(offset, code) // [old_value] — 返り値
          emit_stack_addr(offset, code) // [old_value, addr]
          emit_stack_load(offset, code) // [old_value, addr, old_value2]
          code.push(op_i32_const)
          code.push(b'\x01')
          code.push(op_i32_sub) // [old_value, addr, new_value]
          emit_i32_store(code) // [old_value]
        }
        None =>
          match ctx.resolve(name) {
            Some(index) => {
              // 元の値をスタックに積む（返り値）
              code.push(op_local_get)
              let bytes = @wasm.encode_uleb128(index)
              for b in bytes {
                code.push(b)
              }
              // x - 1 を計算して local に書き戻す
              code.push(op_local_get)
              let bytes2 = @wasm.encode_uleb128(index)
              for b in bytes2 {
                code.push(b)
              }
              code.push(op_i32_const)
              code.push(b'\x01')
              code.push(op_i32_sub)
              emit_local_set(index, code)
            }
            None =>
              raise CodegenError(
                "codegen: 未定義の変数 '" + name + "'",
              )
          }
      }
    UnaryOp(PreInc, _) =>
      raise CodegenError("codegen: ++のオペランドは変数でなければなりません")
    UnaryOp(PreDec, _) =>
      raise CodegenError("codegen: --のオペランドは変数でなければなりません")
    UnaryOp(PostInc, _) =>
      raise CodegenError("codegen: ++のオペランドは変数でなければなりません")
    UnaryOp(PostDec, _) =>
      raise CodegenError("codegen: --のオペランドは変数でなければなりません")
    UnaryOp(Deref, operand) => {
      // *p（間接参照）: operand を評価してアドレスを得て、i32.load で値を読む
      emit_expr(operand, code, ctx) // [addr]
      code.push(op_i32_load)
      code.push(b'\x02') // alignment: 2^2 = 4 bytes
      code.push(b'\x00') // memory offset: 0
    }
    UnaryOp(AddrOf, Ident(name)) =>
      match ctx.stack_vars.get(name) {
        Some(offset) => emit_stack_addr(offset, code)
        None =>
          raise CodegenError(
            "codegen: &\{name} のアドレスを取れません（スタック変数ではありません）",
          )
      }
    UnaryOp(AddrOf, _) =>
      raise CodegenError("codegen: AddrOf のオペランドは変数でなければなりません")
    MemberAccess(base, field_name) => {
      // s.field（右辺値）: ベースアドレス + フィールドオフセットの値をロード
      emit_member_addr(base, field_name, code, ctx) // [field_addr]
      code.push(op_i32_load)
      code.push(b'\x02') // alignment: 2^2 = 4 bytes
      code.push(b'\x00') // memory offset: 0
    }
    SizeOf(type_name) => {
      // sizeof(型名) → コンパイル時定数として i32.const を生成
      let ty = match @sema.resolve_type_name(type_name) {
        Ok(t) => t
        Err(e) => raise CodegenError("codegen: sizeof: " + e)
      }
      let size = size_of_ctype(ty, struct_defs=ctx.struct_defs)
      code.push(op_i32_const)
      for b in @wasm.encode_sleb128(size) {
        code.push(b)
      }
    }
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
      // return 前にエピローグ（SP の復元）を挿入
      emit_epilogue(ctx.frame_size, code)
      code.push(op_return)
    }
    Return(None) => {
      // return 前にエピローグ（SP の復元）を挿入
      emit_epilogue(ctx.frame_size, code)
      code.push(op_return)
    }
    VarDecl(type_name, name, init) => {
      // 変数の型を記録する（ポインタ演算のスケーリングに必要）
      let resolved_type = match @sema.resolve_type_name(type_name) {
        Ok(ty) => {
          ctx.var_types[name] = ty
          Some(ty)
        }
        Err(_) => None
      }
      // 構造体型かどうか判定: 構造体は常にスタック配置（Wasm local に収まらない）
      let is_struct = match resolved_type {
        Some(Struct(_)) => true
        _ => false
      }
      if is_struct {
        // 構造体変数: スタックフレーム上に構造体サイズ分を確保
        let struct_size = match resolved_type {
          Some(Struct(sname)) =>
            match ctx.struct_defs.get(sname) {
              Some(info) => info.total_size
              None =>
                raise CodegenError(
                  "codegen: 未定義の構造体 '" + sname + "'",
                )
            }
          _ => raise CodegenError("codegen: 構造体型の判定に失敗")
        }
        let _offset = ctx.add_struct_stack_var(name, struct_size)
        // 構造体の初期化は現時点では未対応（メンバアクセスタスクで対応）
      } else if ctx.addr_taken.contains(name) {
        // アドレスが取られる変数: スタックフレーム上に配置
        let offset = ctx.add_stack_var(name)
        match init {
          Some(expr) => {
            emit_stack_addr(offset, code) // [addr]
            emit_expr(expr, code, ctx) // [addr, value]
            emit_i32_store(code) // []
          }
          None => ()
        }
      } else {
        // 通常の変数: Wasm local として配置
        let index = ctx.add_local(name)
        match init {
          Some(expr) => {
            emit_expr(expr, code, ctx)
            emit_local_set(index, code)
          }
          None => ()
        }
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
  functions : Map[String, Int],
  struct_defs~ : Map[String, @sema.StructInfo] = {}
) -> @wasm.FuncBody raise CodegenError {
  // 事前スキャン: アドレスが取られる変数を収集
  let addr_taken = collect_addr_taken_vars(body)
  let ctx = CodegenContext::from_params(
    params,
    functions~,
    addr_taken~,
    struct_defs~,
  )
  let code : Array[Byte] = []
  emit_stmt(body, code, ctx)
  // 関数末尾に unreachable を追加
  // 全パスが return で抜ける場合、関数 end 到達時のスタック型チェックを通すため
  code.push(op_unreachable)
  // frame_size > 0 の場合、プロローグをコード先頭に挿入する
  // プロローグ: SP -= frame_size（スタックフレームの確保）
  // 本体コンパイル後に frame_size が確定するため、後から先頭に挿入する
  let final_code = if ctx.frame_size > 0 {
    let prologue : Array[Byte] = []
    emit_prologue(ctx.frame_size, prologue)
    // prologue + code を結合
    for b in code {
      prologue.push(b)
    }
    prologue
  } else {
    code
  }
  // パラメータ以外に追加されたローカル変数の数を計算
  let extra_locals = ctx.next_index - params.length()
  let locals : Array[@wasm.LocalDecl] = if extra_locals > 0 {
    [{ count: extra_locals, valtype: @wasm.I32 }]
  } else {
    []
  }
  { locals, code: final_code }
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
  // 第1パス: 関数名 → function index のマッピングと構造体定義の登録
  // インポート関数の後にユーザー定義関数を配置する
  let functions : Map[String, Int] = {}
  let func_defs : Array[(@ast.TopLevel, Int)] = []
  let mut func_index = num_imports // インポート数分オフセット
  // 構造体定義のレジストリ（sema のシンボルテーブルを使用してレイアウト計算）
  let sym_table = @sema.SymbolTable::new()
  let struct_defs : Map[String, @sema.StructInfo] = {}
  for top_level in program.top_levels {
    match top_level {
      FuncDef(_, name, _, _) => {
        functions[name] = func_index
        func_defs.push((top_level, func_index))
        func_index += 1
      }
      GlobalVarDecl(_, _, _) =>
        raise CodegenError("codegen: グローバル変数は未実装（Phase 4 で実装）")
      StructDef(name, fields) =>
        // 構造体定義を登録: フィールドレイアウトとサイズを計算
        match sym_table.register_struct(name, fields) {
          Ok(info) => struct_defs[name] = info
          Err(e) => raise CodegenError("codegen: 構造体の登録に失敗: " + e)
        }
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
        let fb = compile_function(params, body, functions, struct_defs~)
        func_bodies.push(fb)
      }
      GlobalVarDecl(_, _, _) => () // 上のパスで既にエラーにしているため到達しない
      StructDef(_, _) => () // 構造体定義はコード生成不要
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
  // Global Section: スタックポインタ（SP）を mutable i32 として定義
  // 初期値はメモリの最上位アドレス（1ページ = 65536）
  // スタックは上位アドレスから下位に向かって成長する
  let sp_init_expr = @wasm.make_i32_const_expr(memory_page_size)
  let globals : Array[@wasm.GlobalEntry] = [
    {
      global_type: { valtype: @wasm.I32, mutability: @wasm.Mutable },
      init_expr: sp_init_expr,
    },
  ]
  let global_sec = @wasm.encode_global_section(globals)
  for b in global_sec {
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
