import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/database/seed_files.dart';
import 'data/database/seed_importer.dart';
import 'presentation/state/providers.dart';

/// 启动流程：立即渲染品牌启动页（消除白屏），种子导入后台完成，
/// 就绪后无缝切入主界面。不要改成同步等待，会白屏。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 最后一道兜底：release 包里任何页面渲染异常都显示可读提示，
  // 不再把红屏/堆栈直接甩给用户；debug 保留红屏，方便定位。
  if (kReleaseMode) {
    ErrorWidget.builder = (details) {
      debugPrint('页面渲染异常：${details.exception}');
      return const Material(
        color: Color(0xFFF7F4EF),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_drink_outlined, size: 40),
                SizedBox(height: 12),
                Text('这个页面出了点问题',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('返回上一页再试，或换个关键词搜搜看。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    };
  }

  final db = AppDatabase();
  final ready = ValueNotifier<bool>(false);

  Future<void> startup() async {
    final files = <String, String>{};
    await Future.wait([
      for (final name in kSeedFiles)
        rootBundle
            .loadString('assets/data/$name')
            .then((v) => files[name] = v),
    ]);
    await SeedImporter(db).seedIfNeeded(files);
    ready.value = true;
  }

  unawaited(startup());

  runApp(_BootstrapApp(db: db, ready: ready));
}

class _BootstrapApp extends StatelessWidget {
  const _BootstrapApp({required this.db, required this.ready});

  final AppDatabase db;
  final ValueNotifier<bool> ready;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ready,
      builder: (context, isReady, _) {
        if (!isReady) {
          // 启动页：数据库就绪前的品牌加载态。
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_drink, size: 56),
                    SizedBox(height: 16),
                    Text('啤酒酿造车间助手',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 24),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const BrewApp(),
        );
      },
    );
  }
}
