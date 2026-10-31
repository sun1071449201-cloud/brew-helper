import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 酒精度估算：OG/FG → ABV（简化式 + 精确式）+ 表观/真发酵度。
class AbvPage extends StatefulWidget {
  const AbvPage({super.key});

  @override
  State<AbvPage> createState() => _AbvPageState();
}

class _AbvPageState extends State<AbvPage> {
  final _og = TextEditingController(text: '1.048');
  final _fg = TextEditingController(text: '1.010');

  @override
  void dispose() {
    _og.dispose();
    _fg.dispose();
    super.dispose();
  }

  Map<String, String>? _compute() {
    final og = double.tryParse(_og.text.trim());
    final fg = double.tryParse(_fg.text.trim());
    if (og == null || fg == null || og <= 1 || fg <= 0 || fg > og) return null;
    final simple = QuickTools.abvSimple(og, fg);
    final alt = QuickTools.abvAlternate(og, fg);
    final aa = QuickTools.apparentAttenuation(og, fg);
    final ra = QuickTools.realAttenuation(og, fg);
    return {
      'ABV（简化式）': '${simple.toStringAsFixed(2)} %',
      'ABV（精确式）': '${alt.toStringAsFixed(2)} %',
      '表观发酵度 AA': '${aa.toStringAsFixed(1)} %',
      '真发酵度 RA': '${ra.toStringAsFixed(1)} %',
      '外观糖度差': '${(QuickTools.sgToPlato(og) - QuickTools.sgToPlato(fg)).toStringAsFixed(2)} °P',
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    return Scaffold(
      appBar: AppBar(title: const Text('酒精度估算 ABV')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CalcField(_og, '原麦汁浓度 OG（比重）', '如 1.048'),
          CalcField(_fg, '最终比重 FG（比重）', '如 1.010'),
          const SizedBox(height: 8),
          if (result == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '填入 OG 和 FG（FG 不能大于 OG）。两个读数都要做温度校正后再输入。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            CalcResult(
              rows: result,
              note: '简化式 ±0.5% 量级；精确式在高酒精时更准。正式出厂指标以化验室实测为准。',
            ),
          const SizedBox(height: 12),
          Text(
            '老师傅口径：发酵度看趋势比看单点更有用——每天同一时间测一次 FG，'
            '连续三天不变且双乙酰还原合格，才算发酵结束。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
