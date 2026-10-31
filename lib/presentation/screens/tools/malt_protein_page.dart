import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 麦芽蛋白质换算：总氮 ↔ 蛋白质（干基/风干基互转）。
/// 蛋白质% = 总氮% × 6.25（谷物通用 Jones 系数：大麦蛋白约含 16% 氮）。
/// 风干基（as-is，化验单常用）= 干基 × (1 − 水分%)。
class MaltProteinPage extends StatefulWidget {
  const MaltProteinPage({super.key});

  @override
  State<MaltProteinPage> createState() => _MaltProteinPageState();
}

class _MaltProteinPageState extends State<MaltProteinPage> {
  final _nitrogen = TextEditingController(text: '1.55');
  final _moisture = TextEditingController(text: '5');
  final _proteinAsIs = TextEditingController(text: '9.2');
  final _moisture2 = TextEditingController(text: '5');

  @override
  void initState() {
    super.initState();
    for (final c in [_nitrogen, _moisture, _proteinAsIs, _moisture2]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_nitrogen, _moisture, _proteinAsIs, _moisture2]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String>? _forwardResult() {
    final n = double.tryParse(_nitrogen.text.trim());
    final m = double.tryParse(_moisture.text.trim());
    if (n == null || m == null || n < 0 || m < 0 || m >= 100) return null;
    final dry = QuickTools.proteinFromNitrogen(n);
    final asIs = QuickTools.proteinDryToAsIs(dry, m);
    return {
      '蛋白质（干基）': '${dry.toStringAsFixed(2)} %',
      '蛋白质（风干基，水分 $m%）': '${asIs.toStringAsFixed(2)} %',
      '总氮': '$n %',
    };
  }

  Map<String, String>? _reverseResult() {
    final p = double.tryParse(_proteinAsIs.text.trim());
    final m = double.tryParse(_moisture2.text.trim());
    if (p == null || m == null || p < 0 || m < 0 || m >= 100) return null;
    final dry = QuickTools.proteinAsIsToDry(p, m);
    final n = dry / 6.25;
    return {
      '蛋白质（干基）': '${dry.toStringAsFixed(2)} %',
      '总氮（折算）': '${n.toStringAsFixed(2)} %',
    };
  }

  @override
  Widget build(BuildContext context) {
    final forward = _forwardResult();
    final reverse = _reverseResult();
    return Scaffold(
      appBar: AppBar(title: const Text('麦芽蛋白换算')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('① 总氮 → 蛋白质',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          CalcField(_nitrogen, '总氮 N（%，干基，化验单值）', '如 1.55'),
          CalcField(_moisture, '麦芽水分（%）', '如 5'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.calculate, size: 18),
              label: const Text('计算'),
            ),
          ),
          const SizedBox(height: 4),
          if (forward != null)
            CalcResult(
              rows: forward,
              note: '蛋白质% = 总氮% × 6.25（谷物通用系数）；判级以本厂化验标准为准。',
            ),
          const Divider(height: 24),
          Text('② 蛋白质（风干） → 干基 / 总氮',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          CalcField(_proteinAsIs, '蛋白质（%，风干基）', '如 9.2'),
          CalcField(_moisture2, '麦芽水分（%）', '如 5'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.calculate, size: 18),
              label: const Text('计算'),
            ),
          ),
          const SizedBox(height: 4),
          if (reverse != null)
            CalcResult(
              rows: reverse,
              note: '两张化验单对比时，先统一到干基再比，否则水分差会骗人。',
            ),
          const SizedBox(height: 8),
          Text(
            '老师傅口径：蛋白质看什么？糖化看溶解度（库尔巴哈指数），'
            '泡沫看中分子蛋白，浑浊看高分子蛋白——一个数字管不了三件事。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
