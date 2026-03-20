///|
/// ソースコード上の位置情報
pub(all) struct Loc {
  line : Int
  col : Int
} derive(Eq, Show)

///|
/// トークンとその位置情報
pub(all) struct Token {
  kind : TokenKind
  loc : Loc
} derive(Eq, Show)

///|
/// C 言語サブセットのトークン種別
pub(all) enum TokenKind {
  // キーワード
  KwInt
  KwChar
  KwVoid
  KwStruct
  KwIf
  KwElse
  KwWhile
  KwFor
  KwReturn
  KwSizeof
  // リテラル・識別子
  IntLit(Int)
  CharLit(Char)
  StringLit(String)
  Ident(String)
  // 算術演算子
  Plus       // +
  Minus      // -
  Star       // *
  Slash      // /
  Percent    // %
  // 比較演算子
  EqEq       // ==
  NotEq      // !=
  Lt         // <
  Gt         // >
  LtEq       // <=
  GtEq       // >=
  // 論理演算子
  AmpAmp     // &&
  PipePipe   // ||
  Bang       // !
  // ビット演算子
  Amp        // &
  Pipe       // |
  Caret      // ^
  LtLt       // <<
  GtGt       // >>
  Tilde      // ~
  // 代入・インクリメント
  Eq         // =
  PlusPlus   // ++
  MinusMinus // --
  // 区切り記号
  LParen     // (
  RParen     // )
  LBrace     // {
  RBrace     // }
  LBracket   // [
  RBracket   // ]
  Semicolon  // ;
  Comma      // ,
  Dot        // .
  Arrow      // ->
  // 終端
  Eof
} derive(Eq, Show)
