import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 清洗剂配比：直接投加（kg）+ 原液稀释（C1V1=C2V2）两种算法。
class CleanerMixPage extends StatefulWidget {
  const CleanerMixPage({super.key});

  @override
  State<CleanerMixPage> createState() => _CleanerMixPageState();
}

class _CleanerMixPageState extends State<CleanerMixPage> {
  final _targetPct = TextEditingController(text: '2');
  final _finalLiters = TextEditingController(text: '100');
  final _stockPct = TextEditingController(text: '50');

  @override
  void initState() {
    super.initState();
    for (final c in [_targetPct, _finalLiters, _stockPct]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_targetPct, _finalLiters, _stockPct]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String>? _compute() {
    final target = double.tryParse(_targetPct.text.trim());
    final liters = double.tryParse(_finalLiters.text.trim());
    final stock = double.tryParse(_stockPct.text.trim());
    if (target == null || liters == null || stock == null) return null;
    if (target < 0 || liters <= 0 || stock < 0 || target > stock) return null;

    final kg = QuickTools.doseMassKg(targetPct: target, liters: liters);
    final concL = QuickTools.concentrateVolumeL(
        stockPct: stock, targetPct: target, finalLiters: liters);
    return {
      '直接投加原粉/原碱': '${kg.toStringAsFixed(2)} kg',
      '用 ${stock.toStringAsFixed(1)}% 原液取': '${concL.toStringAsFixed(1)} L',
      '随后补水至': '${liters.toStringAsFixed(0)} L',
      '目标浓度': '${target.toStringAsFixed(2)} %',
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    return Scaffold(
      appBar: AppBar(title: const Text('清洗剂配比')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CalcField(_targetPct, '目标浓度（%）', '如 2（碱洗常用范围，以工艺卡为准）'),
          CalcField(_finalLiters, '配液总量（L）', '如 100（罐容积 − 管路损耗自行评估）'),
          CalcField(_stockPct, '原液浓度（%，用原液时填）', '如 50（液碱标签浓度）'),
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
              note: '投加量按水的密度 1 kg/L 近似；浓度/温度修正与安全限值以本厂 CIP 工艺卡和药剂 MSDS 为准。',
            ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withOpacity(0.4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '安全红线：配碱先加水后加碱（放热剧烈，反着来会溅碱）；'
                '必须戴护目镜和耐碱手套；碱液循环温度高时先降温再取样。',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
