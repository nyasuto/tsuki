/// ソース位置情報
pub(all) struct Pos {
  line : Int
  col : Int
} derive(Show, Eq)

/// Token 型
pub(all) enum Token {
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
  // ファイル終端
  Eof
} derive(Show, Eq)

/// 位置情報付きトークン
pub(all) struct LocToken {
  token : Token
  pos : Pos
} derive(Show, Eq)
