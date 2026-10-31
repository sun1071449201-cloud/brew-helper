import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/reader_markdown.dart';
import '../widgets/states.dart';

/// 安全红线页：CO2 窒息 / 碱液 / 密闭空间 / 热烫伤等，单独成章常驻。
class SafetyPage extends ConsumerWidget {
  const SafetyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(safetyRulesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('安全红线')),
      body: async.when(
        loading: () => const LoadingState(hint: '正在加载安全规范…'),
        error: (e, _) =>
            EmptyState(icon: Icons.error_outline, title: '加载失败：$e'),
        data: (rules) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '下面每一条都是拿事故换来的经验。现场拿不准时：先停手、先通风、先叫人，'
                '再查这条红线。安全永远排在产量前面。',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold, height: 1.5),
              ),
            ),
            const SizedBox(height: 8),
            for (final r in rules)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.gpp_maybe_outlined,
                              size: 17, color: scheme.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(r.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          UnverifiedBadge(text: r.level),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MarkdownBody(
                        data: r.bodyMd,
                        softLineBreak: true,
                        extensionSet: readerMarkdownExtensions,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                                Theme.of(context))
                            .copyWith(
                          p: Theme.of(context).textTheme.bodyMedium,
                          listBullet: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '以上为通用经验整理，正式作业规程以本厂安全管理制度为准。',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
