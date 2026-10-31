import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 单位换算：ppm ↔ mg/L ↔ %（稀溶液近似，密度可修正）。
class UnitConvertPage extends StatefulWidget {
  const UnitConvertPage({super.key});

  @override
  State<UnitConvertPage> createState() => _UnitConvertPageState();
}

class _UnitConvertPageState extends State<UnitConvertPage> {
  final _ppm = TextEditingController(text: '500');
  final _mgL = TextEditingController();
  final _pct = TextEditingController();
  final _density = TextEditingController(text: '1.0');

  @override
  void initState() {
    super.initState();
    _syncPpm('500');
  }

  double get _densityValue {
    final d = double.tryParse(_density.text.trim());
    return (d == null || d <= 0) ? 1.0 : d;
  }

  void _syncPpm(String v) {
    final d = double.tryParse(v);
    if (d == null) {
      _mgL.clear();
      _pct.clear();
      return;
    }
    _mgL.text =
        QuickTools.ppmToMgPerL(d, densityGPerMl: _densityValue).toStringAsFixed(2);
    _pct.text = QuickTools.ppmToPercent(d).toStringAsFixed(5);
  }

  void _syncMgL(String v) {
    final d = double.tryParse(v);
    if (d == null) {
      _ppm.clear();
      _pct.clear();
      return;
    }
    _ppm.text =
        QuickTools.mgPerLToPpm(d, densityGPerMl: _densityValue).toStringAsFixed(2);
    _pct.text =
        QuickTools.ppmToPercent(QuickTools.mgPerLToPpm(d)).toStringAsFixed(5);
  }

  void _syncPct(String v) {
    final d = double.tryParse(v);
    if (d == null) {
      _ppm.clear();
      _mgL.clear();
      return;
    }
    final ppm = QuickTools.percentToPpm(d);
    _ppm.text = ppm.toStringAsFixed(1);
    _mgL.text =
        QuickTools.ppmToMgPerL(ppm, densityGPerMl: _densityValue).toStringAsFixed(2);
  }

  @override
  void dispose() {
    for (final c in [_ppm, _mgL, _pct, _density]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('单位换算 ppm ↔ mg/L ↔ %')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row(context, 'ppm', _ppm, _syncPpm, hint: '如 500（水中溶解物浓度常用单位）'),
          _row(context, 'mg/L', _mgL, _syncMgL, hint: '稀溶液 1 ppm ≈ 1 mg/L'),
          _row(context, '%', _pct, _syncPct, hint: '1% = 10000 ppm'),
          _row(context, '密度修正 g/mL（可选）', _density, (_) {
            // 密度变化时按当前 ppm 重新联动。
            if (_ppm.text.isNotEmpty) _syncPpm(_ppm.text);
          }, hint: '清水/稀溶液 1.0；浓麦汁约 1.04~1.08'),
          const SizedBox(height: 12),
          Text(
            '口径：ppm↔% 为定义换算（精确）；ppm↔mg/L 随密度变化，'
            '水基稀溶液按 1:1 计，浓浆必须做密度修正。化验单换算以计量规程为准。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, TextEditingController c,
      ValueChanged<String> onSync,
      {String? hint}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: c,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: InputDecoration(
                  labelText: label,
                  isDense: true,
                  border: const OutlineInputBorder()),
              onChanged: onSync,
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }
}
