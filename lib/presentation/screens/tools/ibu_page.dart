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

  @override
  void dispose() {
    for (final c in [_aa, _grams, _liters, _sg, _minutes]) {
      c.dispose();
    }
    super.dispose();
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
          const SizedBox(height: 8),
          if (result != null)
            CalcResult(
              rows: result,
              note: 'Tinseth 法为行业常用估算；IBU 无现场快检手段，配方核对以化验室 bitterness 实测为准。',
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
