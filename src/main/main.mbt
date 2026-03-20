fn main {
  let args = @env.args()
  // 引数解析: mucc INPUT.c -o OUTPUT.wasm
  let mut input_file : String = ""
  let mut output_file : String = "out.wasm"
  let mut i = 1 // args[0] はプログラム名
  while i < args.length() {
    if args[i] == "-o" {
      if i + 1 < args.length() {
        output_file = args[i + 1]
        i = i + 2
      } else {
        println("error: -o の後に出力ファイル名が必要です")
        return
      }
    } else {
      input_file = args[i]
      i = i + 1
    }
  }
  if input_file == "" {
    println("usage: mucc INPUT.c [-o OUTPUT.wasm]")
    return
  }
  // ソースファイル読み込み
  let source = mucc_read_file(string_to_cstr(input_file))
  if source.length() == 0 {
    println("error: ファイルを読み込めません: \{input_file}")
    return
  }
  // Lexer: ソースコード → トークン列
  let lexer = @lexer.Lexer::new(source)
  let tokens = match lexer.tokenize() {
    Ok(tokens) => tokens
    Err(e) => {
      println("lexer error: \{e}")
      return
    }
  }
  // Parser: トークン列 → AST
  let parser = @parser.Parser::new(tokens)
  let program = match parser.parse_program() {
    Ok(program) => program
    Err(e) => {
      println("parser error: \{e}")
      return
    }
  }
  // Codegen: AST → Wasm バイナリ
  let wasm_bytes = try {
    @codegen.compile_program(program)
  } catch {
    @codegen.CodegenError(msg) => {
      println("codegen error: \{msg}")
      return
    }
  }
  // .wasm ファイルへの書き出し
  let result = mucc_write_file(
    string_to_cstr(output_file),
    array_byte_to_bytes(wasm_bytes),
  )
  if result != 0 {
    println("error: ファイル書き出しに失敗しました: \{output_file}")
    return
  }
  println("compiled: \{input_file} -> \{output_file}")
}
