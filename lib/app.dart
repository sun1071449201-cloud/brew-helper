import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/state/providers.dart';

class BrewApp extends ConsumerWidget {
  const BrewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    final seedName = ref.watch(seedColorControllerProvider);
    AppTheme.seed = AppTheme.seedOf(seedName);
    return MaterialApp(
      title: '啤酒酿造车间助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const MainShell(),
    );
  }
}
