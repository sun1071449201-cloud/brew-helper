import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 热水用量：投料水温（strike water）+ 醅升温补水量 两种算法。
class HotWaterPage extends StatefulWidget {
  const HotWaterPage({super.key});

  @override
  State<HotWaterPage> createState() => _HotWaterPageState();
}

class _HotWaterPageState extends State<HotWaterPage> {
  // 投料水温
  final _grainTemp = TextEditingController(text: '20');
  final _ratio = TextEditingController(text: '3.0');
  final _targetMash = TextEditingController(text: '66');
  // 升温补水
  final _grainKg = TextEditingController(text: '100');
  final _waterL = TextEditingController(text: '300');
  final _currentC = TextEditingController(text: '60');
  final _raiseTo = TextEditingController(text: '66');
  final _hotC = TextEditingController(text: '95');

  @override
  void initState() {
    super.initState();
    for (final c in [
      _grainTemp,
      _ratio,
      _targetMash,
      _grainKg,
      _waterL,
      _currentC,
      _raiseTo,
      _hotC
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _grainTemp,
      _ratio,
      _targetMash,
      _grainKg,
      _waterL,
      _currentC,
      _raiseTo,
      _hotC
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _strikeResult() {
    final grainTemp = double.tryParse(_grainTemp.text.trim());
    final ratio = double.tryParse(_ratio.text.trim());
    final target = double.tryParse(_targetMash.text.trim());
    if (grainTemp == null || ratio == null || target == null ||
        ratio <= 0 || target <= grainTemp) {
      return {'填入有效参数': '目标醅温要高于粮温'};
    }
    final tw = QuickTools.strikeWaterTemp(
      grainTempC: grainTemp,
      targetMashC: target,
      ratioLPerKg: ratio,
    );
    return {
      '投料水温': '${tw.toStringAsFixed(1)} °C',
      '水粮比': '${ratio.toStringAsFixed(2)} L/kg',
      '目标醅温': '${target.toStringAsFixed(1)} °C',
    };
  }

  Map<String, String> _raiseResult() {
    final grainKg = double.tryParse(_grainKg.text.trim());
    final waterL = double.tryParse(_waterL.text.trim());
    final current = double.tryParse(_currentC.text.trim());
    final target = double.tryParse(_raiseTo.text.trim());
    final hot = double.tryParse(_hotC.text.trim());
    if (grainKg == null ||
        waterL == null ||
        current == null ||
        target == null ||
        hot == null ||
        target <= current ||
        hot <= target) {
      return {'填入有效参数': '热水温要高于目标醅温'};
    }
    final kg = QuickTools.hotWaterKg(
      grainKg: grainKg,
      waterL: waterL,
      currentC: current,
      targetC: target,
      hotC: hot,
    );
    return {
      '补加热水': '${kg.toStringAsFixed(1)} kg（约 ${(kg).toStringAsFixed(1)} L）',
      '升温幅度': '${(target - current).toStringAsFixed(1)} °C',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('热水用量')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('① 投料水温（配投料水）',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          CalcField(_grainTemp, '麦芽温度（°C）', '如 20（车间温度，冬天更低）'),
          CalcField(_ratio, '水粮比（L/kg）', '如 3.0（以工艺卡为准）'),
          CalcField(_targetMash, '目标醅温（°C）', '如 66'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.calculate, size: 18),
              label: const Text('计算'),
            ),
          ),
          const SizedBox(height: 8),
          CalcResult(
            rows: _strikeResult(),
            note: 'Tw = (0.2/r)×(T2−T1)+T2；0.2 为麦芽相对比热经验值，桶体吸热未计入，首罐偏高属正常。',
          ),
          const SizedBox(height: 16),
          Text('② 醅升温补水量（分段糖化升温）',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          CalcField(_grainKg, '麦芽量（kg）', '如 100'),
          CalcField(_waterL, '醅中现有水量（L）', '如 300'),
          CalcField(_currentC, '当前醅温（°C）', '如 60'),
          CalcField(_raiseTo, '目标醅温（°C）', '如 66'),
          CalcField(_hotC, '热水温度（°C）', '如 95'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.calculate, size: 18),
              label: const Text('计算'),
            ),
          ),
          const SizedBox(height: 8),
          CalcResult(
            rows: _raiseResult(),
            note: '补水分 2~3 次加、每次搅拌后测温，别一次灌到位；上限是工艺卡允许的加水量。',
          ),
        ],
      ),
    );
  }
}
