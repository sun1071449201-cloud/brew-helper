import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'fault_page.dart';
import 'glossary_page.dart';
import 'sop_page.dart';
import 'tools/tools_hub_page.dart';

/// 主壳：底部导航四 Tab（SOP 查询 / 工艺计算器 / 异常排查 / 酿造术语）。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 初始化执行一次：读取持久化的主题/色板/字号设置。
    Future.microtask(() {
      ref.read(themeModeControllerProvider.notifier).load();
      ref.read(seedColorControllerProvider.notifier).load();
      ref.read(fontScaleControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          SopPage(),
          ToolsHubPage(),
          FaultPage(),
          GlossaryPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'SOP 查询',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: '计算器',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_circle_outlined),
            selectedIcon: Icon(Icons.build_circle),
            label: '异常排查',
          ),
          NavigationDestination(
            icon: Icon(Icons.translate_outlined),
            selectedIcon: Icon(Icons.translate),
            label: '术语',
          ),
        ],
      ),
    );
  }
}
