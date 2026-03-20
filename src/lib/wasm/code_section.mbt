/// Wasm Code Section のエンコーダ
/// 関数本体（ローカル変数宣言 + 命令列）をエンコードする

/// ローカル変数の宣言（同じ型の連続するローカルをグループ化）
pub(all) struct LocalDecl {
  count : Int
  valtype : ValType
} derive(Show)

/// 関数本体（ローカル変数宣言と命令バイト列）
pub(all) struct FuncBody {
  locals : Array[LocalDecl]
  code : Array[Byte]
} derive(Show)

/// 単一のローカル変数宣言をエンコードする
/// フォーマット: count(uleb128) + valtype(1 byte)
fn encode_local_decl(decl : LocalDecl) -> Array[Byte] {
  let result : Array[Byte] = Array::new(capacity=2)
  let count_bytes = encode_uleb128(decl.count)
  for b in count_bytes {
    result.push(b)
  }
  result.push(decl.valtype.to_byte())
  result
}

/// 単一の関数本体をエンコードする
/// フォーマット: body_size(uleb128) + local_decl_count(uleb128) + local_decl* + code + 0x0B(end)
fn encode_func_body(body : FuncBody) -> Array[Byte] {
  // まず本体の中身を組み立てる
  let inner : Array[Byte] = Array::new(capacity=body.code.length() + 8)
  // ローカル宣言の個数
  let decl_count_bytes = encode_uleb128(body.locals.length())
  for b in decl_count_bytes {
    inner.push(b)
  }
  // 各ローカル宣言
  for decl in body.locals {
    let decl_bytes = encode_local_decl(decl)
    for b in decl_bytes {
      inner.push(b)
    }
  }
  // 命令列
  for b in body.code {
    inner.push(b)
  }
  // end 命令（0x0B）
  inner.push(b'\x0B')
  // body_size + 中身
  let result : Array[Byte] = Array::new(capacity=inner.length() + 5)
  let size_bytes = encode_uleb128(inner.length())
  for b in size_bytes {
    result.push(b)
  }
  for b in inner {
    result.push(b)
  }
  result
}

/// Code Section 全体をエンコードする
/// フォーマット: section_id(0x0A) + size(uleb128) + count(uleb128) + func_body*
pub fn encode_code_section(bodies : Array[FuncBody]) -> Array[Byte] {
  let payload : Array[Byte] = Array::new(capacity=32)
  // 関数本体の個数
  let count_bytes = encode_uleb128(bodies.length())
  for b in count_bytes {
    payload.push(b)
  }
  // 各関数本体
  for body in bodies {
    let body_bytes = encode_func_body(body)
    for b in body_bytes {
      payload.push(b)
    }
  }
  encode_section(SecCode, payload)
}
