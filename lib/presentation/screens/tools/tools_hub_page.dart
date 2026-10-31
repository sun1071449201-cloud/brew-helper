import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'abv_page.dart';
import 'cleaner_mix_page.dart';
import 'co2_page.dart';
import 'hot_water_page.dart';
import 'ibu_page.dart';
import 'sugar_priming_page.dart';
import 'sg_convert_page.dart';
import 'unit_convert_page.dart';

/// 工具条目。
class _Tool {
  const _Tool(this.key, this.name, this.desc, this.icon, this.builder);
  final String key;
  final String name;
  final String desc;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Tab 2：工艺计算器工具宫格。分类展示 + 长按置顶（持久化到 app_settings）。
/// 新增计算器三件套：QuickTools 函数 + test 用例 + 注册进本页 _calcTools。
class ToolsHubPage extends ConsumerStatefulWidget {
  const ToolsHubPage({super.key});

  @override
  ConsumerState<ToolsHubPage> createState() => _ToolsHubPageState();
}

class _ToolsHubPageState extends ConsumerState<ToolsHubPage> {
  static const _pinKey = 'pinned_tools';

  static const _calcTools = <_Tool>[
    _Tool('sg', '比重换算', 'SG ↔ GU ↔ °P', Icons.science, _mkSg),
    _Tool('abv', '酒精度估算', 'OG/FG → ABV + 发酵度', Icons.local_bar, _mkAbv),
    _Tool('ibu', '酒花苦度 IBU', 'Tinseth 法', Icons.grass, _mkIbu),
    _Tool('sugar', '补糖计算', '碳酸化目标 → 加糖克数', Icons.water_drop, _mkSugar),
    _Tool('cleaner', '清洗剂配比', '碱液/酸液投加与稀释', Icons.sanitizer, _mkCleaner),
    _Tool('unit', '单位换算', 'ppm ↔ mg/L ↔ %', Icons.swap_horiz, _mkUnit),
  ];

  static const _refTools = <_Tool>[
    _Tool('hotwater', '热水用量', '投料水温 / 升温补水', Icons.thermostat, _mkHot),
    _Tool('co2', 'CO2 含量对照', '温度 × 压力 → 体积数', Icons.bubble_chart, _mkCo2),
  ];

  /// 帮助文案：输入什么 / 输出什么 / 什么时候别信它。
  static const _helpTexts = <String, List<String>>{
    '比重换算': ['SG / GU / °P 任一项', '另外两项换算结果', '°P 换算在 1.000~1.100 SG 外误差变大'],
    '酒精度估算': ['OG / FG（比重计读数）', 'ABV%、表观/真发酵度', '简化式 ±0.5% 量级；温度未校正先校正'],
    '酒花苦度 IBU': ['AA%、酒花克数、煮沸升数、SG、分钟', 'IBU（Tinseth 法）', '是估算不是实测；老酒花 AA 会衰减'],
    '补糖计算': ['目标体积数、残余体积数、酒量、糖种', '加糖克数', '按化学计量推导；实际以本厂碳酸化工艺卡为准'],
    '清洗剂配比': ['目标浓度% × 配液量（或原液浓度）', '投加 kg / 原液升数', '碱液有放热与腐蚀，先加水后加碱，穿戴防护'],
    '单位换算': ['数值 + 单位', 'ppm / mg/L / % 三向换算', '稀溶液近似 1 ppm = 1 mg/L；浓浆需按密度修正'],
    '热水用量': ['粮温、水粮比、目标醅温', '投料水温 / 升温补水量', '0.2 比热为经验常数；桶体吸热未计入'],
    'CO2 含量对照': ['酒温 + 表压（或目标体积数）', '饱和 CO2 体积数 / 所需压力', '亨利定律按水近似；酒精含量会略降溶解度'],
  };

  static Widget _mkSg(_) => const SgConvertPage();
  static Widget _mkAbv(_) => const AbvPage();
  static Widget _mkIbu(_) => const IbuPage();
  static Widget _mkSugar(_) => const SugarPrimingPage();
  static Widget _mkCleaner(_) => const CleanerMixPage();
  static Widget _mkUnit(_) => const UnitConvertPage();
  static Widget _mkHot(_) => const HotWaterPage();
  static Widget _mkCo2(_) => const Co2Page();

  Set<String> _pinned = {};

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    final v = await ref.read(settingsRepositoryProvider).get(_pinKey);
    if (!mounted || v == null || v.isEmpty) return;
    try {
      final list = (jsonDecode(v) as List).cast<String>();
      setState(() => _pinned = list.toSet());
    } catch (_) {
      // 坏数据忽略，视为无置顶
    }
  }

  Future<void> _togglePin(String key) async {
    setState(() {
      if (_pinned.contains(key)) {
        _pinned.remove(key);
      } else {
        _pinned.add(key);
      }
    });
    await ref
        .read(settingsRepositoryProvider)
        .set(_pinKey, jsonEncode(_pinned.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final all = [..._calcTools, ..._refTools];
    final pinned = [
      for (final t in all)
        if (_pinned.contains(t.key)) t,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('工艺计算器'),
        actions: [
          if (_pinned.isNotEmpty)
            IconButton(
              tooltip: '清空置顶',
              icon: const Icon(Icons.clear_all, size: 20),
              onPressed: () async {
                setState(() => _pinned = {});
                await ref.read(settingsRepositoryProvider).set(_pinKey, '[]');
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (pinned.isNotEmpty) ...[
            _sectionHeader(context, '⭐ 常用（长按取消）'),
            _grid(context, pinned, isPinnedSection: true),
            const SizedBox(height: 8),
          ],
          _sectionHeader(context, '🧮 计算类'),
          _grid(context, _calcTools),
          const SizedBox(height: 8),
          _sectionHeader(context, '📖 查表类'),
          _grid(context, _refTools),
          const SizedBox(height: 8),
          Text('长按任意工具可置顶/取消置顶，置顶保存在本机。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context, _Tool tool) {
    final help = _helpTexts[tool.key];
    if (help == null || help.length < 3) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tool.name,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _helpRow(ctx, Icons.input, '输入', help[0]),
            const SizedBox(height: 8),
            _helpRow(ctx, Icons.output, '输出', help[1]),
            const SizedBox(height: 8),
            _helpRow(ctx, Icons.warning_amber_outlined, '别信它', help[2]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(ctx).push(
                      MaterialPageRoute(builder: tool.builder));
                },
                child: const Text('打开工具'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpRow(BuildContext context, IconData icon, String label, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary)),
        ),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12.5, height: 1.4)),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _grid(BuildContext context, List<_Tool> tools,
      {bool isPinnedSection = false}) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        for (final t in tools)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: t.builder)),
              onLongPress: () => _togglePin(t.key),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(t.icon,
                        size: 26,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(t.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                            ),
                            if (isPinnedSection)
                              const Icon(Icons.push_pin,
                                  size: 11,
                                  color: Colors.orange),
                          ]),
                          const SizedBox(height: 2),
                          Text(t.desc,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.help_outline, size: 16),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onPressed: () => _showHelp(context, t),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
