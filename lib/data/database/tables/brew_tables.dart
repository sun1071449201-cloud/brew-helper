import 'package:drift/drift.dart';

/// SOP 工序条目（Tab1 主数据源；FTS 全文检索）。
/// process: 糖化 / 发酵 / CIP / 过滤 / 灌装 / 包装。
class SopProcedures extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sopId => text().unique()();
  TextColumn get process => text()();
  TextColumn get title => text()();
  TextColumn get bodyMd => text()();
  TextColumn get keywords => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get sourceRef => text().nullable()();
}

/// 工艺参数速查（各工序典型参数区间；verified=false = 经验参考，以本厂 SOP 为准）。
class ProcessParams extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get paramId => text().unique()();
  TextColumn get process => text()();
  TextColumn get name => text()();
  TextColumn get valueRange => text()();
  TextColumn get note => text().nullable()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get sourceRef => text().nullable()();
}

/// 异常排查条目（Tab3 主数据源）：症状 → 可能原因 → 排查步骤 → 对策。
class FaultDiagnosis extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get faultId => text().unique()();
  TextColumn get process => text()();
  TextColumn get symptom => text()();
  TextColumn get causeMd => text()();
  TextColumn get stepsMd => text()();
  TextColumn get remedyMd => text()();
  TextColumn get keywords => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get sourceRef => text().nullable()();
}

/// 计算公式卡（与工具宫格互跳：toolKey 对应 tools_hub 注册键）。
class CalcFormulas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get formulaId => text().unique()();
  TextColumn get name => text()();
  TextColumn get formulaMd => text()();
  TextColumn get variablesMd => text()();
  TextColumn get explanationMd => text()();
  TextColumn get exampleMd => text()();
  TextColumn get toolKey => text().nullable()();
  TextColumn get keywords => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get sourceRef => text().nullable()();
}

/// 酿造术语库（中英双语，Tab4 主数据源；FTS 检索 + 背诵模式）。
class GlossaryTerms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get termId => text().unique()();
  TextColumn get en => text()();
  TextColumn get zh => text()();
  TextColumn get category => text()();
  TextColumn get definition => text()();
  TextColumn get note => text().nullable()();
  TextColumn get keywords => text()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get sourceRef => text().nullable()();
}

/// 安全规范（CO2 / 碱液 / 密闭空间等安全红线，单独成章）。
class SafetyRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ruleId => text().unique()();
  TextColumn get title => text()();
  TextColumn get level => text().withDefault(const Constant('安全红线'))();
  TextColumn get bodyMd => text()();
  TextColumn get keywords => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get sourceRef => text().nullable()();
}

/// 每日知识点池（"今日一课"数据源；chapterKey/anchor 可跳转书籍章节）。
class DailyFacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get factId => text().unique()();
  TextColumn get title => text()();
  TextColumn get bodyMd => text()();
  TextColumn get category => text()();
  TextColumn get chapterKey => text().nullable()();
  TextColumn get anchor => text().nullable()();
  TextColumn get keywords => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get sourceRef => text().nullable()();
}
