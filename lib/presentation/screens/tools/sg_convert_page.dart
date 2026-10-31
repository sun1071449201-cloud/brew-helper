import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 比重换算：SG ↔ GU ↔ °P 三向实时换算。
class SgConvertPage extends StatefulWidget {
  const SgConvertPage({super.key});

  @override
  State<SgConvertPage> createState() => _SgConvertPageState();
}

class _SgConvertPageState extends State<SgConvertPage> {
  final _sg = TextEditingController(text: '1.048');
  final _gu = TextEditingController(text: '48');
  final _plato = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncSg('1.048');
  }

  void _syncSg(String v) {
    final d = double.tryParse(v);
    if (d == null || d <= 0) {
      _gu.clear();
      _plato.clear();
      return;
    }
    _gu.text = QuickTools.sgToGu(d).toStringAsFixed(1);
    _plato.text = QuickTools.sgToPlato(d).toStringAsFixed(2);
  }

  void _syncGu(String v) {
    final d = double.tryParse(v);
    if (d == null) {
      _sg.clear();
      _plato.clear();
      return;
    }
    final sg = QuickTools.guToSg(d);
    _sg.text = sg.toStringAsFixed(4);
    _plato.text = QuickTools.sgToPlato(sg).toStringAsFixed(2);
  }

  void _syncPlato(String v) {
    final d = double.tryParse(v);
    if (d == null) {
      _sg.clear();
      _gu.clear();
      return;
    }
    final sg = QuickTools.platoToSg(d);
    _sg.text = sg.toStringAsFixed(4);
    _gu.text = QuickTools.sgToGu(sg).toStringAsFixed(1);
  }

  @override
  void dispose() {
    for (final c in [_sg, _gu, _plato]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('比重换算 SG ↔ GU ↔ °P')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row(context, '比重 SG', _sg, _syncSg,
              hint: '如 1.048（比重计读数，先做温度校正）'),
          _row(context, '重力单位 GU', _gu, _syncGu,
              hint: 'GU = (SG − 1) × 1000'),
          _row(context, '柏拉图 °P', _plato, _syncPlato,
              hint: '糖度计读数；车间里两种计都有，先看清标尺'),
          const SizedBox(height: 12),
          Text(
            '口径：SG→°P 用 ASBC 多项式；°P→SG 用 Balling 近似式。'
            '换算结果为参考值，交接记录以本厂计量规程为准。',
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
