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
  // 演算子
  Plus       // +
  Minus      // -
  Star       // *
  Slash      // /
  Percent    // %
  Eq         // ==
  Ne         // !=
  Lt         // <
  Gt         // >
  Le         // <=
  Ge         // >=
  And        // &&
  Or         // ||
  Amp        // &
  Pipe       // |
  Caret      // ^
  Shl        // <<
  Shr        // >>
  Bang       // !
  Tilde      // ~
  Inc        // ++
  Dec        // --
  Assign     // =
  // 区切り記号
  LParen     // (
  RParen     // )
  LBrace     // {
  RBrace     // }
  LBracket   // [
  RBracket   // ]
  Semi       // ;
  Comma      // ,
  Dot        // .
  Arrow      // ->
  // ファイル終端
  Eof
} derive(Show, Eq)

/// 位置情報付きトークン
pub(all) struct LocToken {
  token : Token
  pos : Pos
} derive(Show, Eq)
