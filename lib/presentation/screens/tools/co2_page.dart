import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// CO2 含量对照：酒温+表压 → 饱和体积数；或酒温+目标体积数 → 所需表压。
class Co2Page extends StatefulWidget {
  const Co2Page({super.key});

  @override
  State<Co2Page> createState() => _Co2PageState();
}

class _Co2PageState extends State<Co2Page> {
  final _temp = TextEditingController(text: '4');
  final _pressure = TextEditingController(text: '0.8');
  final _target = TextEditingController(text: '2.5');

  @override
  void dispose() {
    for (final c in [_temp, _pressure, _target]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String>? _forward() {
    final temp = double.tryParse(_temp.text.trim());
    final pressure = double.tryParse(_pressure.text.trim());
    if (temp == null || pressure == null || pressure < 0) return null;
    final vol = QuickTools.co2Volumes(tempC: temp, pressureBarGauge: pressure);
    return {
      '饱和 CO2 含量': '${vol.toStringAsFixed(2)} vol',
      '（约）': '${(vol * 1.9621).toStringAsFixed(1)} g/L',
    };
  }

  Map<String, String>? _reverse() {
    final temp = double.tryParse(_temp.text.trim());
    final target = double.tryParse(_target.text.trim());
    if (temp == null || target == null || target < 0) return null;
    final bar =
        QuickTools.pressureForVolumes(tempC: temp, volumes: target);
    return {
      '所需表压': '${bar.toStringAsFixed(2)} bar',
      '目标 CO2': '${target.toStringAsFixed(2)} vol @ ${temp.toStringAsFixed(1)} °C',
    };
  }

  @override
  Widget build(BuildContext context) {
    final forward = _forward();
    final reverse = _reverse();
    return Scaffold(
      appBar: AppBar(title: const Text('CO2 含量对照')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CalcField(_temp, '酒温（°C）', '如 4（背压/碳酸化时的酒液温度）'),
          CalcField(_pressure, '罐内表压（bar）', '如 0.8（压力表读数）'),
          const SizedBox(height: 8),
          if (forward != null)
            CalcResult(
              rows: forward,
              note: '亨利定律（Sander 2015 关联式，按水近似）；酒精含量会略降溶解度，结果与查表值差 0.1~0.2 vol 属正常。',
            ),
          const Divider(),
          CalcField(_target, '目标 CO2 体积数（vol）', '如 2.5（以工艺卡为准）'),
          const SizedBox(height: 8),
          if (reverse != null)
            CalcResult(
              rows: reverse,
              note: '反算表压为稳态平衡值；背压操作要“先背压后降温”，波动时以工艺卡的对照表为准。',
            ),
          const SizedBox(height: 12),
          Text(
            '老师傅口径：罐顶压力表 ≠ 酒液 CO2。温度一变，溶解度马上变——'
            '取样测 CO2 要在规定酒温下测，不然白测。CO2 置换作业先看安全红线。',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
