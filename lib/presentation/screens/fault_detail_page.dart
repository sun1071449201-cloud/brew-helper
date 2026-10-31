import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../state/providers.dart';
import '../widgets/reader_markdown.dart';
import '../widgets/states.dart';

/// 故障详情页：症状 → 可能原因 → 排查步骤 → 对策（四段式卡片）。
class FaultDetailPage extends ConsumerWidget {
  const FaultDetailPage({super.key, required this.faultId});

  final String faultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_faultDetailProvider(faultId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.search_off,
          title: '没有找到这条故障记录',
          subtitle: e.toString(),
        ),
      ),
      data: (fault) => _FaultDetailView(fault: fault),
    );
  }
}

final _faultDetailProvider =
    FutureProvider.family<FaultDiagnosi, String>((ref, faultId) async {
  final fault = await ref.watch(faultRepositoryProvider).byFaultId(faultId);
  if (fault == null) throw StateError('未找到故障条目：$faultId');
  return fault;
});

class _FaultDetailView extends StatelessWidget {
  const _FaultDetailView({required this.fault});

  final FaultDiagnosi fault;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(fault.process, style: const TextStyle(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_outlined, size: 18, color: scheme.error),
              const SizedBox(width: 6),
              const UnverifiedBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text('症状：${fault.symptom}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 19)),
          const SizedBox(height: 12),
          _sectionCard(
            context,
            icon: Icons.help_outline,
            title: '为什么会出现（可能原因）',
            color: scheme.secondary,
            md: fault.causeMd,
          ),
          _sectionCard(
            context,
            icon: Icons.checklist,
            title: '现场怎么排查（一步一步来）',
            color: scheme.primary,
            md: fault.stepsMd,
          ),
          _sectionCard(
            context,
            icon: Icons.build_circle_outlined,
            title: '对策（处理与预防）',
            color: scheme.tertiary,
            md: fault.remedyMd,
          ),
          const SizedBox(height: 8),
          Text(
            '来源：${fault.sourceRef ?? '以本厂 SOP 为准'} · 本条为经验整理，处置前核对车间现行工艺卡。',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required String md,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 6),
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            MarkdownBody(
              data: md,
              softLineBreak: true,
              extensionSet: readerMarkdownExtensions,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyMedium,
                listBullet: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
