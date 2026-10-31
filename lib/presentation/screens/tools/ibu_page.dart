import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 酒花苦度 IBU（Tinseth 法）：AA% × 克数 × 煮沸时间 → IBU 估算。
class IbuPage extends StatefulWidget {
  const IbuPage({super.key});

  @override
  State<IbuPage> createState() => _IbuPageState();
}

class _IbuPageState extends State<IbuPage> {
  final _aa = TextEditingController(text: '10');
  final _grams = TextEditingController(text: '30');
  final _liters = TextEditingController(text: '100');
  final _sg = TextEditingController(text: '1.050');
  final _minutes = TextEditingController(text: '60');
  // 分次添加汇总（第 1~3 次）
  final _aa2 = TextEditingController(text: '8');
  final _grams2 = TextEditingController(text: '50');
  final _minutes2 = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    for (final c in [_aa, _grams, _liters, _sg, _minutes, _aa2, _grams2, _minutes2]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_aa, _grams, _liters, _sg, _minutes, _aa2, _grams2, _minutes2]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 分次添加汇总：两次添加分别算再相加（第 3 行留空即按两次计）。
  Map<String, String>? _totalResult() {
    final liters = double.tryParse(_liters.text.trim());
    final sg = double.tryParse(_sg.text.trim());
    final aa1 = double.tryParse(_aa.text.trim());
    final g1 = double.tryParse(_grams.text.trim());
    final m1 = double.tryParse(_minutes.text.trim());
    final aa2 = double.tryParse(_aa2.text.trim());
    final g2 = double.tryParse(_grams2.text.trim());
    final m2 = double.tryParse(_minutes2.text.trim());
    if (liters == null || sg == null || aa1 == null || g1 == null || m1 == null) {
      return null;
    }
    final adds = <({double aaPercent, double grams, double minutes})>[
      (aaPercent: aa1, grams: g1, minutes: m1),
    ];
    if (aa2 != null && g2 != null && m2 != null) {
      adds.add((aaPercent: aa2, grams: g2, minutes: m2));
    }
    final total = QuickTools.ibuTotal(liters: liters, sg: sg, additions: adds);
    return {'分次合计 IBU': total.toStringAsFixed(1), '添加次数': '${adds.length} 次'};
  }

  Map<String, String>? _compute() {
    final aa = double.tryParse(_aa.text.trim());
    final grams = double.tryParse(_grams.text.trim());
    final liters = double.tryParse(_liters.text.trim());
    final sg = double.tryParse(_sg.text.trim());
    final minutes = double.tryParse(_minutes.text.trim());
    if (aa == null ||
        grams == null ||
        liters == null ||
        sg == null ||
        minutes == null) {
      return null;
    }
    if (liters <= 0 || aa < 0 || grams < 0 || sg <= 1 || minutes < 0) {
      return null;
    }
    final util = QuickTools.tinsethUtilization(sg, minutes);
    final ibu = QuickTools.ibuTinseth(
        aaPercent: aa, grams: grams, liters: liters, sg: sg, minutes: minutes);
    return {
      'IBU 估算': ibu.toStringAsFixed(1),
      '甲酸利用率': '${(util * 100).toStringAsFixed(1)} %',
      '甲酸添加量': '${(aa / 100 * grams * 1000 / liters).toStringAsFixed(0)} mg/L',
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    return Scaffold(
      appBar: AppBar(title: const Text('酒花苦度 IBU')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CalcField(_aa, '酒花 α-酸含量 AA（%）', '如 10（看酒花包装标注）'),
          CalcField(_grams, '酒花用量（g）', '如 30'),
          CalcField(_liters, '煮沸麦汁量（L）', '如 100'),
          CalcField(_sg, '煮沸时麦汁比重 SG', '如 1.050'),
          CalcField(_minutes, '煮沸时间（分钟）', '如 60'),
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
          if (result != null)
            CalcResult(
              rows: result,
              note: 'Tinseth 法为行业常用估算；IBU 无现场快检手段，配方核对以化验室 bitterness 实测为准。',
            ),
          const SizedBox(height: 12),
          Text('分次添加汇总（第 2 次可选）',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          CalcField(_aa2, '第 2 次酒花 AA（%）', '如 8（留空则按单次计）'),
          CalcField(_grams2, '第 2 次酒花用量（g）', '如 50'),
          CalcField(_minutes2, '第 2 次煮沸时间（分钟）', '如 10'),
          const SizedBox(height: 4),
          if (_totalResult() != null)
            CalcResult(
              rows: _totalResult()!,
              note: '每次添加的利用率差别很大——必须分别算再相加，不能把克数相加套一次公式。',
            ),
          const SizedBox(height: 12),
          Text(
            '老师傅口径：晚加 10 分钟，利用率掉一截；分次添加时要分别算再相加。'
            '酒花存放会掉酸，库存超过半年的先降 10% 估。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
