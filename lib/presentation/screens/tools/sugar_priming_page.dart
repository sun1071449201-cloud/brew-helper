import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 补糖计算：目标 CO2 体积数 → 加糖克数（按糖种区分化学计量）。
class SugarPrimingPage extends StatefulWidget {
  const SugarPrimingPage({super.key});

  @override
  State<SugarPrimingPage> createState() => _SugarPrimingPageState();
}

class _SugarPrimingPageState extends State<SugarPrimingPage> {
  final _target = TextEditingController(text: '2.5');
  final _residual = TextEditingController(text: '1.2');
  final _liters = TextEditingController(text: '100');
  SugarKind _kind = SugarKind.sucrose;

  @override
  void dispose() {
    for (final c in [_target, _residual, _liters]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String>? _compute() {
    final target = double.tryParse(_target.text.trim());
    final residual = double.tryParse(_residual.text.trim());
    final liters = double.tryParse(_liters.text.trim());
    if (target == null || residual == null || liters == null) return null;
    if (target < 0 || residual < 0 || liters <= 0 || target < residual) {
      return null;
    }
    final grams = QuickTools.primingSugarGrams(
      targetVol: target,
      residualVol: residual,
      liters: liters,
      kind: _kind,
    );
    return {
      '补糖量': '${grams.toStringAsFixed(0)} g',
      '单位用量': '${(grams / liters).toStringAsFixed(2)} g/L',
      '需提升 CO2': '${(target - residual).toStringAsFixed(2)} vol',
      '糖种': _kind.label,
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    return Scaffold(
      appBar: AppBar(title: const Text('补糖计算')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CalcField(_target, '目标 CO2 体积数（vol）', '如 2.5（以工艺卡为准）'),
          CalcField(_residual, '残余 CO2 体积数（vol）', '如 1.2（发酵结束时酒温对应值）'),
          CalcField(_liters, '待补酒量（L）', '如 100'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('糖种', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final k in SugarKind.values)
                        ChoiceChip(
                          label: Text(k.label,
                              style: const TextStyle(fontSize: 12)),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (result == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('目标体积数要大于残余体积数；不确定残余量时按发酵末期酒温查工艺卡。',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            )
          else
            CalcResult(
              rows: result,
              note: '用量按糖的化学计量推导（STP 换算）；实际溶解受酒温影响，分罐操作前以本厂碳酸化工艺卡复核。',
            ),
          const SizedBox(height: 12),
          Text(
            '老师傅口径：糖先化成 1:1 糖浆再分装，否则容易局部过甜、杀菌时爆瓶。'
            '补完糖要倒罐混匀，取样测一下再做下一罐。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
