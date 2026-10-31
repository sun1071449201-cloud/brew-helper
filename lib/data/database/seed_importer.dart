import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';

/// Seed importer: transactionally imports assets/data JSON into SQLite.
/// Idempotent: skips when seed_meta version + checksum are unchanged.
/// JSON 格式为对象数组：[{"id":"...", "title":"...", "body_md":"...", ...}]。
///
/// 用户数据保护（覆盖安装不清空用户数据）：
/// - userTables 跳过集合：reading_progress / bookmarks / search_history / favorites；
/// - app_settings：导入前先读出旧值，导入后按用户值覆盖回默认值之上。
///   新增任何存用户行为的表，必须加进 userTables，否则覆盖安装会清空用户数据。
class SeedImporter {
  SeedImporter(this._db);

  final AppDatabase _db;

  static const seedVersion = '0.1.0';
  static const datasetName = 'brew_seed_pack';

  Future<void> seedIfNeeded(Map<String, String> files) async {
    final buf = StringBuffer();
    for (final key in files.keys.toList()..sort()) {
      buf
        ..write(key)
        ..write('=')
        ..write(files[key])
        ..write('\n');
    }
    final checksum = md5.convert(utf8.encode(buf.toString())).toString();

    final existing = await (_db.select(_db.seedMeta)
          ..where((t) => t.datasetName.equals(datasetName)))
        .getSingleOrNull();
    if (existing != null &&
        existing.version == seedVersion &&
        existing.checksum == checksum) {
      return;
    }

    // app_settings 是用户数据：先记下现有值，导入完再覆盖回默认值之上。
    // 否则每次加/改种子数据都会把主题、字号、置顶工具重置。
    final savedSettings = await (_db.select(_db.appSettings)).get();

    await _db.transaction(() async {
      // 用户数据表不随种子导入清库（书签/进度/收藏/搜索历史/每日知识/已读/背诵保留）。
      const userTables = {
        'reading_progress',
        'bookmarks',
        'search_history',
        'favorites',
        'daily_history',
        'chapter_read_marks',
        'glossary_progress',
      };
      for (final table in _db.allTables) {
        if (userTables.contains(table.actualTableName)) continue;
        await _db.delete(table).go();
      }
      await _insertAll(files);
      // 恢复用户设置（不覆盖新版本的默认键，只覆盖用户实际改过的键）。
      for (final s in savedSettings) {
        await _db.into(_db.appSettings).insertOnConflictUpdate(
              AppSettingsCompanion.insert(key: s.key, value: s.value),
            );
      }
      await _db.into(_db.seedMeta).insert(SeedMetaCompanion.insert(
            datasetName: datasetName,
            version: seedVersion,
            checksum: checksum,
          ));
    });

    // SOP / 故障 / 术语的 FTS 索引随种子重建（trigram 分词，支持中文子串检索）。
    await _db.rebuildSopFts();
    await _db.rebuildFaultFts();
    await _db.rebuildGlossaryFts();
  }

  // ---------- parsing（对象数组格式） ----------

  List<Map<String, dynamic>> _rows(Map<String, String> files, String fileName) {
    final raw = files[fileName];
    if (raw == null) throw StateError('Missing seed file: $fileName');
    final decoded = jsonDecode(raw) as List;
    return [
      for (final row in decoded) row as Map<String, dynamic>,
    ];
  }

  String _s(Map<String, dynamic> r, String k) => r[k] as String;
  int _i(Map<String, dynamic> r, String k) => (r[k] as num?)?.round() ?? 0;
  bool _b(Map<String, dynamic> r, String k) => (r[k] as bool?) ?? false;
  String? _sn(Map<String, dynamic> r, String k) => r[k] as String?;

  // ---------- validation + write ----------

  Future<void> _insertAll(Map<String, String> files) async {
    final sop = _rows(files, 'sop_procedures.json');
    final params = _rows(files, 'process_params.json');
    final faults = _rows(files, 'fault_diagnosis.json');
    final formulas = _rows(files, 'calc_formulas.json');
    final glossary = _rows(files, 'glossary_terms.json');
    final safety = _rows(files, 'safety_rules.json');
    final dailyFacts = _rows(files, 'daily_facts.json');
    final settings = _rows(files, 'app_settings.json');

    const processes = {'糖化', '发酵', 'CIP', '过滤', '灌装', '包装', '通用'};

    void require(bool cond, String message) {
      if (!cond) throw StateError('Seed validation failed: $message');
    }

    for (final r in sop) {
      require(processes.contains(_s(r, 'process')),
          'sop_procedures unknown process ${_s(r, 'process')}');
    }
    for (final r in params) {
      require(processes.contains(_s(r, 'process')),
          'process_params unknown process ${_s(r, 'process')}');
    }
    for (final r in faults) {
      require(processes.contains(_s(r, 'process')),
          'fault_diagnosis unknown process ${_s(r, 'process')}');
    }

    await _db.batch((b) {
      b.insertAll(_db.sopProcedures, [
        for (final r in sop)
          SopProceduresCompanion(
            sopId: Value(_s(r, 'sop_id')),
            process: Value(_s(r, 'process')),
            title: Value(_s(r, 'title')),
            bodyMd: Value(_s(r, 'body_md')),
            keywords: Value(_s(r, 'keywords')),
            sort: Value(_i(r, 'sort')),
            verified: Value(_b(r, 'verified')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.processParams, [
        for (final r in params)
          ProcessParamsCompanion(
            paramId: Value(_s(r, 'param_id')),
            process: Value(_s(r, 'process')),
            name: Value(_s(r, 'name')),
            valueRange: Value(_s(r, 'value_range')),
            note: Value(_sn(r, 'note')),
            sort: Value(_i(r, 'sort')),
            verified: Value(_b(r, 'verified')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.faultDiagnosis, [
        for (final r in faults)
          FaultDiagnosisCompanion(
            faultId: Value(_s(r, 'fault_id')),
            process: Value(_s(r, 'process')),
            symptom: Value(_s(r, 'symptom')),
            causeMd: Value(_s(r, 'cause_md')),
            stepsMd: Value(_s(r, 'steps_md')),
            remedyMd: Value(_s(r, 'remedy_md')),
            keywords: Value(_s(r, 'keywords')),
            sort: Value(_i(r, 'sort')),
            verified: Value(_b(r, 'verified')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.calcFormulas, [
        for (final r in formulas)
          CalcFormulasCompanion(
            formulaId: Value(_s(r, 'formula_id')),
            name: Value(_s(r, 'name')),
            formulaMd: Value(_s(r, 'formula_md')),
            variablesMd: Value(_s(r, 'variables_md')),
            explanationMd: Value(_s(r, 'explanation_md')),
            exampleMd: Value(_s(r, 'example_md')),
            toolKey: Value(_sn(r, 'tool_key')),
            keywords: Value(_s(r, 'keywords')),
            sort: Value(_i(r, 'sort')),
            verified: Value(_b(r, 'verified')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.glossaryTerms, [
        for (final r in glossary)
          GlossaryTermsCompanion(
            termId: Value(_s(r, 'term_id')),
            en: Value(_s(r, 'en')),
            zh: Value(_s(r, 'zh')),
            category: Value(_s(r, 'category')),
            definition: Value(_s(r, 'definition')),
            note: Value(_sn(r, 'note')),
            keywords: Value(_s(r, 'keywords')),
            verified: Value(_b(r, 'verified')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.safetyRules, [
        for (final r in safety)
          SafetyRulesCompanion(
            ruleId: Value(_s(r, 'rule_id')),
            title: Value(_s(r, 'title')),
            level: Value(_s(r, 'level')),
            bodyMd: Value(_s(r, 'body_md')),
            keywords: Value(_s(r, 'keywords')),
            sort: Value(_i(r, 'sort')),
            verified: Value(_b(r, 'verified')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.dailyFacts, [
        for (final r in dailyFacts)
          DailyFactsCompanion(
            factId: Value(_s(r, 'fact_id')),
            title: Value(_s(r, 'title')),
            bodyMd: Value(_s(r, 'body_md')),
            category: Value(_s(r, 'category')),
            chapterKey: Value(_sn(r, 'chapter_key')),
            anchor: Value(_sn(r, 'anchor')),
            keywords: Value(_s(r, 'keywords')),
            sort: Value(_i(r, 'sort')),
            verified: Value(_b(r, 'verified')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.appSettings, [
        for (final r in settings)
          AppSettingsCompanion(
            key: Value(_s(r, 'key')),
            value: Value(_s(r, 'value')),
          ),
      ]);
    });
  }
}
