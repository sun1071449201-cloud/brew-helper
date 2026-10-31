import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 计算器通用输入行：标签 + 数字键盘输入框（各计算页共用）。
class CalcField extends StatelessWidget {
  const CalcField(this.c, this.label, this.hint, {super.key});

  final TextEditingController c;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          TextField(
            controller: c,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(isDense: true, hintText: hint),
          ),
        ],
      ),
    );
  }
}

/// 计算器通用结果卡：键值对纵向排列（各计算页共用）。
class CalcResult extends StatelessWidget {
  const CalcResult({super.key, required this.rows, this.note});

  final Map<String, String> rows;

  /// 结果下方的口径说明（如“以本厂工艺卡为准”）。
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('结果', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: '复制结果',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    final text = rows.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('结果已复制')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text(e.key,
                            style: const TextStyle(fontSize: 12))),
                    Expanded(
                        flex: 2,
                        child: Text(e.value,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(
                note!,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
