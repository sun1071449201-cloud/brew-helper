import 'package:markdown/markdown.dart' as md;

/// 书籍/详情页共用的 Markdown 扩展。
///
/// 保留表格、emoji、自动链接；**去掉 GFM 删除线**。
/// 原因：工艺数据大量用单个波浪号表示范围（如 "62~65°C、2~3 bar"），
/// Dart markdown 的 StrikethroughSyntax 用 `~+` 做定界符，会把两段范围
/// 之间的正文整段划掉。工程手册不需要删除线，关掉最稳。
final md.ExtensionSet readerMarkdownExtensions = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  <md.InlineSyntax>[
    for (final syntax in md.ExtensionSet.gitHubFlavored.inlineSyntaxes)
      if (syntax is! md.StrikethroughSyntax) syntax,
  ],
);
