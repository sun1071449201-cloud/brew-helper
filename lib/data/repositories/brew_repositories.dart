import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// SOP 工序条目仓库：FTS5 trigram 全文检索（<3 字符回退 LIKE），按工序过滤。
class DriftSopRepository {
  DriftSopRepository(this._db);

  final AppDatabase _db;

  Future<List<SopProcedure>> all() async {
    return await (_db.select(_db.sopProcedures)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<List<SopProcedure>> byProcess(String process) async {
    return await (_db.select(_db.sopProcedures)
          ..where((t) => t.process.equals(process))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<SopProcedure?> bySopId(String sopId) async {
    return await (_db.select(_db.sopProcedures)
          ..where((t) => t.sopId.equals(sopId)))
        .getSingleOrNull();
  }

  /// FTS 检索：query ≥3 runes 走 sop_fts，否则 LIKE 兜底（短词/单词）。
  Future<List<SopProcedure>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return all();
    if (q.runes.length >= 3) {
      final escaped = q.replaceAll("'", "''");
      final rows = await _db.customSelect(
        'SELECT s.* FROM sop_fts f JOIN sop_procedures s ON s.id = f.rowid '
        'WHERE sop_fts MATCH ? '
        'ORDER BY s.sort, s.id LIMIT 100',
        variables: [Variable('"$escaped"')],
      ).get();
      return rows.map((r) => _mapSop(r.data)).toList();
    }
    final like = '%$q%';
    return await (_db.select(_db.sopProcedures)
          ..where((t) =>
              t.title.like(like) |
              t.bodyMd.like(like) |
              t.keywords.like(like))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.id),
          ])
          ..limit(100))
        .get();
  }

  SopProcedure _mapSop(Map<String, dynamic> r) => SopProcedure(
        id: r['id'] as int,
        sopId: r['sop_id'] as String,
        process: r['process'] as String,
        title: r['title'] as String,
        bodyMd: r['body_md'] as String,
        keywords: r['keywords'] as String,
        sort: (r['sort'] as int?) ?? 0,
        verified: ((r['verified'] as int?) ?? 0) != 0,
        sourceRef: r['source_ref'] as String?,
      );
}

/// 异常排查仓库：症状 FTS 检索。
class DriftFaultRepository {
  DriftFaultRepository(this._db);

  final AppDatabase _db;

  Future<List<FaultDiagnosi>> all() async {
    return await (_db.select(_db.faultDiagnosis)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<FaultDiagnosi?> byFaultId(String faultId) async {
    return await (_db.select(_db.faultDiagnosis)
          ..where((t) => t.faultId.equals(faultId)))
        .getSingleOrNull();
  }

  Future<List<FaultDiagnosi>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return all();
    if (q.runes.length >= 3) {
      final escaped = q.replaceAll("'", "''");
      final rows = await _db.customSelect(
        'SELECT f0.* FROM fault_fts ff JOIN fault_diagnosis f0 ON f0.id = ff.rowid '
        'WHERE fault_fts MATCH ? '
        'ORDER BY f0.sort, f0.id LIMIT 100',
        variables: [Variable('"$escaped"')],
      ).get();
      return rows.map((r) => _mapFault(r.data)).toList();
    }
    final like = '%$q%';
    return await (_db.select(_db.faultDiagnosis)
          ..where((t) =>
              t.symptom.like(like) |
              t.causeMd.like(like) |
              t.stepsMd.like(like) |
              t.keywords.like(like))
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.id),
          ])
          ..limit(100))
        .get();
  }

  FaultDiagnosi _mapFault(Map<String, dynamic> r) => FaultDiagnosi(
        id: r['id'] as int,
        faultId: r['fault_id'] as String,
        process: r['process'] as String,
        symptom: r['symptom'] as String,
        causeMd: r['cause_md'] as String,
        stepsMd: r['steps_md'] as String,
        remedyMd: r['remedy_md'] as String,
        keywords: r['keywords'] as String,
        sort: (r['sort'] as int?) ?? 0,
        verified: ((r['verified'] as int?) ?? 0) != 0,
        sourceRef: r['source_ref'] as String?,
      );
}

/// 术语仓库：中英 FTS 双向检索。
class DriftGlossaryRepository {
  DriftGlossaryRepository(this._db);

  final AppDatabase _db;

  Future<List<GlossaryTerm>> all() async {
    return await (_db.select(_db.glossaryTerms)
          ..orderBy([
            (t) => OrderingTerm.asc(t.category),
            (t) => OrderingTerm.asc(t.en),
          ]))
        .get();
  }

  Future<List<GlossaryTerm>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return all();
    if (q.runes.length >= 3) {
      final escaped = q.replaceAll("'", "''");
      final rows = await _db.customSelect(
        'SELECT g.* FROM glossary_fts f JOIN glossary_terms g ON g.id = f.rowid '
        'WHERE glossary_fts MATCH ? '
        'ORDER BY g.category, g.en LIMIT 100',
        variables: [Variable('"$escaped"')],
      ).get();
      return rows.map((r) => _mapTerm(r.data)).toList();
    }
    final like = '%$q%';
    return await (_db.select(_db.glossaryTerms)
          ..where((t) =>
              t.en.like(like) | t.zh.like(like) | t.definition.like(like))
          ..orderBy([
            (t) => OrderingTerm.asc(t.category),
            (t) => OrderingTerm.asc(t.en),
          ])
          ..limit(100))
        .get();
  }

  GlossaryTerm _mapTerm(Map<String, dynamic> r) => GlossaryTerm(
        id: r['id'] as int,
        termId: r['term_id'] as String,
        en: r['en'] as String,
        zh: r['zh'] as String,
        category: r['category'] as String,
        definition: r['definition'] as String,
        note: r['note'] as String?,
        keywords: r['keywords'] as String,
        verified: ((r['verified'] as int?) ?? 0) != 0,
        sourceRef: r['source_ref'] as String?,
      );
}

/// 工艺参数 / 公式卡 / 安全规范（浏览型数据源）。
class DriftBrewTablesRepository {
  DriftBrewTablesRepository(this._db);

  final AppDatabase _db;

  Future<List<ProcessParam>> processParams([String? process]) async {
    return await (_db.select(_db.processParams)
          ..where((t) {
            // 不能把 Dart bool 与 Expression<bool> 用 || 混写，这里显式分支。
            if (process == null || process.isEmpty) {
              return const Constant(true);
            }
            return t.process.equals(process);
          })
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<List<CalcFormula>> calcFormulas() async {
    return await (_db.select(_db.calcFormulas)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Future<List<SafetyRule>> safetyRules() async {
    return await (_db.select(_db.safetyRules)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sort),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }
}
