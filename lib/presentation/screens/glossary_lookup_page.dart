import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/states.dart';

/// 划词 → 术语查询结果页（酿造术语库 FTS 检索）。
class GlossaryLookupPage extends ConsumerWidget {
  const GlossaryLookupPage({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(glossaryQueryProvider(query));
    return Scaffold(
      appBar: AppBar(title: Text('术语：$query')),
      body: resultsAsync.when(
        loading: () => const LoadingState(hint: '正在检索术语库…'),
        error: (e, _) => Center(child: Text('查询失败：$e')),
        data: (terms) => terms.isEmpty
            ? EmptyState(
                icon: Icons.search_off,
                title: '术语库中没有匹配“$query”的词条',
                subtitle: '试试英文单词或中文关键词',
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final t in terms)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(t.en,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Text('${t.zh} · ${t.definition}'),
                        isThreeLine: false,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
