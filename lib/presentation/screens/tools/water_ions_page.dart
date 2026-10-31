import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 水离子计算：酿造盐投加 → 水中离子浓度贡献（正向），或目标浓度 → 需盐量（反向）。
/// 离子质量分数由摩尔质量直接算出（定义换算）：
///   石膏 CaSO4·2H2O M=172.17：Ca 40.08→0.2328，SO4 96.06→0.5579
///   氯化钙 CaCl2·2H2O M=147.01：Ca→0.2726，Cl 70.90→0.4823
///   泻盐 MgSO4·7H2O M=246.47：Mg 24.31→0.0986，SO4→0.3897
///   氯化镁 MgCl2·6H2O M=203.30：Mg→0.1196，Cl→0.3488
///   食盐 NaCl M=58.44：Na 22.99→0.3934，Cl→0.6066
///   小苏打 NaHCO3 M=84.01：Na→0.2737，HCO3 61.02→0.7263
class WaterIonsPage extends StatefulWidget {
  const WaterIonsPage({super.key});

  @override
  State<WaterIonsPage> createState() => _WaterIonsPageState();
}

class _Salt {
  const _Salt(this.name, this.ions);
  final String name;
  final List<(String, double)> ions; // (离子标签, 质量分数)
}

class _WaterIonsPageState extends State<WaterIonsPage> {
  static const _salts = <_Salt>[
    _Salt('石膏 CaSO4·2H2O', [('Ca²⁺', 0.2328), ('SO₄²⁻', 0.5579)]),
    _Salt('氯化钙 CaCl2·2H2O', [('Ca²⁺', 0.2726), ('Cl⁻', 0.4823)]),
    _Salt('泻盐 MgSO4·7H2O', [('Mg²⁺', 0.0986), ('SO₄²⁻', 0.3897)]),
    _Salt('氯化镁 MgCl2·6H2O', [('Mg²⁺', 0.1196), ('Cl⁻', 0.3488)]),
    _Salt('食盐 NaCl', [('Na⁺', 0.3934), ('Cl⁻', 0.6066)]),
    _Salt('小苏打 NaHCO3', [('Na⁺', 0.2737), ('HCO₃⁻', 0.7263)]),
  ];

  int _saltIndex = 0;
  final _grams = TextEditingController(text: '5');
  final _liters = TextEditingController(text: '100');
  int _ionIndex = 0;
  final _targetPpm = TextEditingController(text: '50');
  final _liters2 = TextEditingController(text: '100');
  final _caPpm = TextEditingController(text: '40');
  final _mgPpm = TextEditingController(text: '10');

  _Salt get _salt => _salts[_saltIndex];

  @override
  void initState() {
    super.initState();
    for (final c in [_grams, _liters, _targetPpm, _liters2, _caPpm, _mgPpm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_grams, _liters, _targetPpm, _liters2, _caPpm, _mgPpm]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _hardnessResult() {
    final ca = double.tryParse(_caPpm.text.trim());
    final mg = double.tryParse(_mgPpm.text.trim());
    if (ca == null || mg == null || ca < 0 || mg < 0) {
      return {'填入有效参数': '钙镁浓度 ≥ 0'};
    }
    final caDh = QuickTools.calciumToDh(ca);
    final mgDh = QuickTools.magnesiumToDh(mg);
    return {
      '钙硬度': '${caDh.toStringAsFixed(2)} °dH',
      '镁硬度': '${mgDh.toStringAsFixed(2)} °dH',
      '总硬度': '${QuickTools.totalHardnessDh(caPpm: ca, mgPpm: mg).toStringAsFixed(2)} °dH',
    };
  }

  Map<String, String> _forwardResult() {
    final grams = double.tryParse(_grams.text.trim());
    final liters = double.tryParse(_liters.text.trim());
    if (grams == null || liters == null || grams < 0 || liters <= 0) {
      return {'填入有效参数': '盐克数 ≥ 0，水量 > 0'};
    }
    final out = <String, String>{};
    for (final ion in _salt.ions) {
      final ppm = QuickTools.ionPpm(
          grams: grams, liters: liters, fraction: ion.$2);
      out['${ion.$1} 贡献'] = '${ppm.toStringAsFixed(1)} ppm (mg/L)';
    }
    return out;
  }

  Map<String, String> _reverseResult() {
    final ppm = double.tryParse(_targetPpm.text.trim());
    final liters = double.tryParse(_liters2.text.trim());
    if (ppm == null || liters == null || ppm < 0 || liters <= 0) {
      return {'填入有效参数': '目标浓度 ≥ 0，水量 > 0'};
    }
    if (_ionIndex >= _salt.ions.length) _ionIndex = 0;
    final ion = _salt.ions[_ionIndex];
    final grams = QuickTools.ionGrams(
        ppm: ppm, liters: liters, fraction: ion.$2);
    return {
      '需投 ${_salt.name}': '${grams.toStringAsFixed(2)} g',
      '目标 ${ion.$1}': '${ppm.toStringAsFixed(1)} ppm @ ${liters.toStringAsFixed(0)} L',
    };
  }

  @override
  Widget build(BuildContext context) {
    final forward = _forwardResult();
    final reverse = _reverseResult();
    return Scaffold(
      appBar: AppBar(title: const Text('水离子计算')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('① 投盐 → 离子浓度',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _saltSelector(),
          CalcField(_grams, '盐量（g）', '如 5'),
          CalcField(_liters, '水量（L）', '如 100'),
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
          CalcResult(
            rows: forward,
            note: '离子质量分数按纯盐化学计量换算；工业盐纯度不足时结果按比例打折，以药剂标签为准。',
          ),
          const Divider(height: 24),
          Text('② 目标浓度 → 需盐量',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          _saltSelector(),
          if (_salt.ions.length > 1)
            _ionSelector(),
          CalcField(_targetPpm, '目标离子浓度（ppm）', '如 50'),
          CalcField(_liters2, '水量（L）', '如 100'),
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
          CalcResult(
            rows: reverse,
            note: '水质调整是全局账：多种盐会互相贡献离子，先定钙再配氯硫，一次只动一个变量并送检复核。',
          ),
          const Divider(height: 24),
          Text('③ 硬度换算（°dH 德国度）',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          CalcField(_caPpm, '钙 Ca²⁺（ppm）', '如 40'),
          CalcField(_mgPpm, '镁 Mg²⁺（ppm）', '如 10'),
          const SizedBox(height: 4),
          CalcResult(
            rows: _hardnessResult(),
            note: '1 °dH = 17.848 mg/L CaCO3 当量；钙系数 2.4972、镁系数 4.1176 均由摩尔质量换算。原水硬度以化验单为准。',
          ),
          const SizedBox(height: 8),
          Text(
            '老师傅口径：酿造水调整先看本厂原水化验单，别照抄配方书的盐量——'
            '各地水源差得远。加什么、加多少，工艺员签字才算数。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _saltSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButton<int>(
          isExpanded: true,
          value: _saltIndex,
          underline: const SizedBox.shrink(),
          items: [
            for (var i = 0; i < _salts.length; i++)
              DropdownMenuItem(value: i, child: Text(_salts[i].name,
                  style: const TextStyle(fontSize: 13))),
          ],
          onChanged: (v) => setState(() {
            _saltIndex = v ?? 0;
            if (_ionIndex >= _salt.ions.length) _ionIndex = 0;
          }),
        ),
      ),
    );
  }

  Widget _ionSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 8,
        children: [
          for (var i = 0; i < _salt.ions.length; i++)
            ChoiceChip(
              label: Text(_salt.ions[i].$1,
                  style: const TextStyle(fontSize: 12)),
              selected: _ionIndex == i,
              onSelected: (_) => setState(() => _ionIndex = i),
            ),
        ],
      ),
    );
  }
}
