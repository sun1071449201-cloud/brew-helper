# README_FOR_AI — 项目交接文档（写给下一个接手的 AI / 开发者）

> 啤酒酿造车间一线操作员辅助学习 App（Flutter 离线 App）
> 当前版本：v5（pubspec `0.5.0+5`，2026-11-01 绿构建）。schemaVersion=4，17 张 Drift 表 + 3 张 FTS5 虚表；仓库已转 public。
> 内容取向（2026-11-01 用户定）：**生产实操优先于安全生产**——新增内容以操作判断、现场处置为主，安全类降后进自扩展池。
> 架构模式源自"机械精度与几何公差"App，内容域全部替换为酿造。
> 本文档假设你已会 Dart/Flutter，重点是"这个项目有什么约定、坑在哪、数据怎么改"。

---

## 1. 一页总览

- **App 定位**：酿造车间一线操作员口袋工具。4 个底部 Tab：SOP 查询 / 工艺计算器 / 异常排查 / 酿造术语；书籍模块（5 本酿造手册）从 SOP 页右上角进入；SOP 页顶部是"今日知识点"卡片、右上角"统计"是学习统计页。
- **核心约束**：**完全离线**运行（云端只用于编译 APK）。所有数据随 APK 资产内置。
- **数据红线**：所有工艺参数（温度/时间/浓度/比重/压力）一律 `verified: false` + `source_ref: "以本厂 SOP 为准"`。**禁止编造任何酿造参数**。没有依据的数值宁可写成经验描述，不许冒充标准。
- **内容口吻**：所有内容必须是"老工程师带徒弟"——先讲为什么 → 再讲怎么避坑 → 最后讲现场怎么检查。禁止写成"应在适宜条件下进行"这种空话。
- **规模（v3）**：SOP 18 条 / 工艺参数 22 行 / 故障 16 条 / 公式 8 条 / 术语 100 词 / 安全红线 8 条 / 每日知识点 60 条；5 本书 22 章。
- **本仓库不含 android/ 壳**：CI 用 `flutter create .` 现场生成（见 §5）。

## 2. 技术栈与依赖

| 依赖 | 版本 | 用途 |
|---|---|---|
| Flutter / Dart | 3.24.0 stable / SDK ≥3.3.0 | 框架（升级会连锁触发 lint/兼容问题） |
| drift / drift_dev | 2.20.0 | SQLite ORM（12 张表，代码生成） |
| sqlite3_flutter_libs | 0.5.24 | SQLite 原生库 |
| flutter_riverpod | 2.5.1 | 状态管理 |
| flutter_markdown / markdown | 0.7.4 / 7.2.2 | 书籍与详情渲染 |
| crypto | 3.0.3 | 种子指纹/幂等 |
| build_runner | 2.4.11 | Drift 代码生成 |

- pubspec 依赖**锁死照抄**，不引入新依赖。
- Material 3；主题种子色 4 色板（amber 默认，app_settings `seed_color`）；`ZoomPageTransitionsBuilder`。
- **Flutter 3.24 红线**：用 `WidgetStateProperty`（`MaterialStateProperty` 已废弃）；用 `withOpacity`（禁 `withValues`）；Record 不支持 `[]` 索引。

## 3. 目录结构

```
├─ .github/workflows/build_apk.yml   # 云端 APK 构建（ubuntu + Flutter 3.24 + JDK 17）
├─ assets/
│  ├─ data/                          # 7 个 JSON：种子数据（对象数组格式），随 APK 内置
│  ├─ books/                         # 3 本书：manifest.json + 每本一个子目录的 Markdown
│  └─ branding/app_icon.png          # 启动图标（flutter_launcher_icons）
├─ lib/
│  ├─ data/database/                 # Drift 表定义 + AppDatabase(schemaVersion=1) + 种子导入器
│  ├─ data/repositories/             # 仓库层（brew_repositories / user_data_repositories / book_repositories）
│  ├─ domain/services/quick_tools.dart  # 全部计算器引擎（静态纯函数）
│  ├─ presentation/screens/          # 页面（screens/tools/ 下是 8 个计算器页）
│  ├─ presentation/state/providers.dart # Riverpod 中枢
│  └─ presentation/widgets/          # calc_widgets / states / reader_markdown
├─ test/                             # 5 个测试文件（quick_tools / seed_import / book_repository / brew_repositories / schema_smoke）
├─ tool/                             # CI 脚本（github_upload.ps1 / ci_debug.ps1 / clean_artifacts.py / configure_android_release.py / validate_book_content.py）
├─ apk_versions/                     # 各里程碑 APK 存档（v1 已归档，不参与编译）
└─ README_FOR_AI.md                  # 本文档
```

## 4. 架构要点（改动前必读）

0. **每 2~3 个小任务推一次 CI**（analyze 零 issue + test 全绿才算过；本地无 Flutter SDK，全部走 GitHub Actions）。
1. **启动引导**（`lib/main.dart`）：先渲染品牌启动页，后台异步加载种子文件，`ValueListenableBuilder` 就绪后切到正式 App（`ProviderScope` overrides database）。**不要改成同步等待**，会白屏。
2. **种子导入幂等**（`seed_importer.dart`）：checksum 相同跳过；导入前先读出 app_settings 旧值，导入后覆盖回用户值。**userTables 跳过集合**（reading_progress / bookmarks / search_history / favorites）是覆盖安装时唯一保护用户数据的机制——**新增任何存用户行为的表必须加进这个集合**，否则用户数据被清空。
3. **FTS5 全文搜索**：sop_fts / fault_fts / glossary_fts 全部 trigram tokenizer，随种子导入全量重建。**查询 <3 字符必须回退 LIKE**（三个仓库的 search() 都有此分支，照抄别删）。FTS MATCH 查询串要包引号且转义单引号（`'"$escaped"'`）。
4. **Drift 命名规则（v1 实证）**：Companion 类名 = 表类名 + `Companion`（如 `AppSettingsCompanion`、`FaultDiagnosisCompanion`）；数据类名 = 表类名去掉尾部 s（`SopProcedures`→`SopProcedure`、`FaultDiagnosis`→`FaultDiagnosi`），**不以 s 结尾的表数据类会加 Data 后缀**（`SearchHistory`→`SearchHistoryData`）——所以 user_data_repositories 不直接引用 SearchHistory 行类名，用自建 `HistoryEntry`。别自作聪明引用，写了必编译错。
5. **Drift 写入一律 Companion + Value() 包可选列**；表列名不能用 `text`。
6. **计算器**：公式全部在 `quick_tools.dart` 静态纯函数；**新增计算器三件套 = QuickTools 函数 + test/quick_tools_test.dart 用例 + 注册进 tools_hub_page.dart 的 _calcTools/_refTools**。测试期望值必须用公式重算并把算式写进注释（参考项目两次心算翻车）。
7. **公共组件**：`calc_widgets.dart`（CalcField/CalcResult）、`states.dart`（LoadingState/EmptyState/FadeIn/UnverifiedBadge）直接复用，不要再写本地输入框和结果卡。
8. **`ref.listen` 只能写在 `ConsumerWidget.build()` 顶层**；"初始化执行一次"用 `addPostFrameCallback` + bool 守卫（sop_detail 的收藏状态就是范例）。
9. **书籍锚点**：章节按 `##`/`###` 分段渲染；跳转 payload `{chapterKey, anchor}`；anchor=节号（如 "1.2"）按完整节号匹配（不会误跳 1.2.1）。
10. **删除线语法禁用**：`reader_markdown.dart` 去掉 GFM strikethrough——酿造数据大量用 `62~65` 这种波浪号，删除线语法会把两段范围之间的正文整段划掉（参考项目 911 N·m 事故）。

## 5. 编译打包（全部云端）

**仓库已转 public（2026-10-31）**：公开仓库 Actions 分钟无限，绕开私有仓库月底配额封锁（转公开前已核验 main 分支无 PAT/密钥/密码文件——uploader 脚本的 exclude 清单负责拦截，**新增敏感文件必须加进 exclude 清单**）。签名密钥只存 repo Secrets 与本地备份，公开的只是代码。

本地无 Flutter SDK。CI 流程（build_apk.yml）：checkout → JDK17 → Flutter 3.24.0 → `flutter create .`（brew_helper / com.sunliangyu）→ sed 补 Kotlin 1.9.24 → 配签名 → rm 模板 widget_test → pub get → build_runner → flutter_launcher_icons → **python3 tool/validate_book_content.py（内容门禁）** → analyze → test → build apk → 产物直推 `apk-builds` 分支（不走 artifact，配额会爆；artifact 步骤保留但 continue-on-error + 3 天过期）。

```powershell
tool/github_token.txt        # PAT（repo+workflow 权限），gitignore 保护，不入库
tool/github_upload.ps1       # 建 repo（sun1071449201-cloud/brew-helper）+ Git Data API 全量推送 + 触发构建
tool/github_upload.ps1 -Poll # 轮询直到绿
tool/ci_debug.ps1 -RunId <id># 拉失败日志到 tool/build_log.txt
tool/clean_artifacts.py      # 清 artifact 配额（keep=N）
```

### 签名（覆盖安装的生命线）

- repo Secrets 已配置：`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`。
- **keystore 的来历（v1 实际方案）**：本机没有 JDK/keytool，且 GitHub artifact 存储配额已被参考项目占满（artifact 上传步骤永远静默失败，continue-on-error 掩盖了它），所以 v1 用 Python `cryptography` 在本地生成 PKCS12 keystore（RSA 2048 + 自签证书 CN=Brew Helper，等价 keytool -storetype PKCS12 产物），经 pynacl sealed-box 写入上述 4 个 Secrets。备份在 `tool/keystore_backup/`（gitignore 保护）。**丢失备份 = 以后无法覆盖安装升级，必须妥善保存。**
- workflow 里保留了一条"Secrets 缺失时 CI 现场生成临时 keystore"的兜底分支，但**其 artifact 带出路线因配额已不可用**；正常情况下永远走不到这个分支。
- v1 交付 APK（`apk_versions/v1/`）已做签名核验：APK 内 META-INF 证书指纹与备份 keystore 一致。
- applicationId 固化 `com.sunliangyu.brew_helper`（flutter create --org com.sunliangyu），不许改。

## 6. 数据库与数据文件

### 6.1 Drift 表（schemaVersion=4）

**种子表**（导入器清空重灌）：SopProcedures / ProcessParams / FaultDiagnosis / CalcFormulas / GlossaryTerms / SafetyRules / DailyFacts / SeedMeta。

**用户表**（导入器保护）：AppSettings（另有保存恢复逻辑）/ ReadingProgress / Bookmarks / SearchHistory / Favorites / DailyHistory / ChapterReadMarks / GlossaryProgress / ChapterLearningProgress。

**FTS5 虚表**（SQL 手建）：sop_fts(title, body, keywords) / fault_fts(symptom, cause, steps, keywords) / glossary_fts(en, zh, definition)，均 trigram。

**改库三件套**（一条不许少）：表类 → schemaVersion+1 → AppDatabase migration（迁移链：v2 每日知识 → v3 已读/背诵 → v4 章节学习）；用户表加进 userTables 跳过集合；同时补 migration 测试。

### 6.1.2 章节学习卡（v4 新增）

- 数据链：assets/data/book_learning.json（14 个实操内容章，42 题）→ BookLearningService.load() → 阅读页"本章速览"卡 + "测 3 题"弹窗。
- 判定口径：quiz **3 题全对 → status 2（掌握）**，否则 1（看过）；学习行为 touchStudyStreak 计入连续天数。
- 出题红线：quiz 答案必须能从该章原文找到依据（validate 脚本校验 quiz 结构、answer 越界、缺 explanation、summary<3、chapter_key 不在 manifest）。
- markChapterLearning 用 insertOnConflictUpdate 是安全的（主键 chapterKey 已提供，不属坑 13 场景）；坑 13 只针对 uniqueKeys 约束。

### 6.1.1 每日知识点与学习统计（v2/v3）

- 每日知识：daily_facts.json → DailyService.candidates(now)（30 天去重 + 当日稳定排序）→ SOP 页 DailyTipCard；markShown 用 delete-then-insert 幂等。
- 学习统计：StudyService.touch 在三类学习行为（标记已读 / 背术语 / 看每日知识卡）时累计连续天数（study_streak / last_study_date 两个 app_settings 键，断一天重置 1）。统计页数据：readMarks + glossaryProgress + favorites/bookmarks 计数 + dailyHistory 去重数。
- 术语背诵：GlossaryProgress（status 0/1/2，间隔 1/3/7/30/60 天，dueAt 到期提醒）；markGlossaryTerm 已背/还不熟，clearGlossaryTerm 恢复未背。
- "继续上次阅读"：阅读页滚动/离开时写 last_read_chapter / last_read_chapter_title / last_read_book_title / last_read_percent 四个 app_settings 键，书架页 lastReadInfoProvider 读取。

### 6.1.1 每日知识点（v2 新增）

- 数据链：assets/data/daily_facts.json（40 条）→ daily_facts 表 → `DailyService.candidates(now)` 当日稳定排序 → SOP 页顶部 DailyTipCard。
- 选择算法：30 天内展示过的不进候选池（DailyHistory）；池空回退全池；排序键 = (sort×31 + dayHash(dayKey)) % 100003，同一天稳定。
- markShown 写 dayKey+factId（幂等）并清理 30 天外记录；卡片首次展示/换一条都会记。
- 改知识池只动 daily_facts.json，改完跑 validate 脚本（≥40 条门禁）。

### 6.2 种子 JSON（assets/data/，对象数组格式）

```jsonc
// sop_procedures.json — 每条字段必须齐全，缺了导入直接失败
[{ "sop_id": "sop_mash_in", "process": "糖化", "title": "糖化投料作业",
   "body_md": "投料不是倒进去就完事…", "keywords": "糖化 投料 醅温",
   "sort": 1, "verified": false, "source_ref": "以本厂 SOP 为准" }]
// 故障条目：cause_md（为什么）/ steps_md（排查步骤）/ remedy_md（对策）
// 公式条目：formula_md / variables_md / explanation_md / example_md / tool_key（跳转工具宫格键）
// 术语条目：en / zh / category / definition / note（老师傅提醒）
```

- `verified` 全部 false（有人核对后才能置 true 并补真实标准号）；`source_ref` 必填。
- process 取值限定：糖化/发酵/CIP/过滤/灌装/包装/通用（导入器校验）。
- 改完 JSON 跑 `python tool/validate_book_content.py`（本地可跑，CI 也会跑）。

### 6.3 书籍（assets/books/）

- manifest.json：books[] 每章 `{key, title, file}`；**key 全局唯一**（`ferm_sop.ch01` 式）。
- 每章 md：一级标题=章名；`## `/`###` 是锚点定位单位，**每章必须至少有一个 `## `**（validate 脚本强制）。
- **新增章节三步**：写 md → manifest 追加 → pubspec assets 无需改（子目录已声明）。**新增书**：md 目录 + manifest + pubspec assets 加目录声明（目录不递归！）+ book_repository_test 书数断言。

## 7. 已知坑速查（改代码前扫一遍）

1. analyze 视 info 为失败：const/unused/插值全要清；map 值是纯 String 表达式时不要包 `${}`。
2. PowerShell 5.1 脚本只写 ASCII；**不要用脚本正则往 YAML/JSON 里插行**（丢缩进），用精确编辑。
3. 单元测试期望值必须用公式重算并写算式进注释。
4. 测试里用 rootBundle 前先 `TestWidgetsFlutterBinding.ensureInitialized()`。
5. FTS 查询 <3 字符回退 LIKE；FTS MATCH 词要带引号防注入/语法错；**trigram 对 <3 字符查询匹配不到任何行**（测试里直接查 FTS 虚表时也要用 ≥3 字词）。
6. pubspec assets 目录声明不递归。
7. `FutureProvider.family` 的参数参与缓存键——Tab 页里搜索词变会自动重查，别手动缓存。
8. 书签跳转的 segmentIndex 与内容强耦合：正文改动后旧书签段落可能错位，阅读页已做越界兜底（提示而非崩溃）。
9. 清洗剂/CO2/补糖这类公式是**经验/推导值**，UI 上一律带"以本厂工艺卡为准"的口径说明（CalcResult 的 note 参数）。
10. **GitHub artifact 配额已爆**（本账号被参考项目占满）：所有 upload-artifact 步骤都会静默失败（continue-on-error 掩盖），产物必须走 apk-builds 分支，不要依赖 artifact 交付任何东西。
11. `contents` API 对 >1MB 文件不返回 content——从分支下载 APK 要走 **git blob API**（`/git/blobs/{sha}`，base64 全量返回）。
12. drift 的 `where` 闭包里不能把 Dart `bool` 与 `Expression<bool>` 用 `||` 混写——分支判断要么提到闭包外，要么返回 `Constant(true)`。
13. **`insertOnConflictUpdate` 的冲突目标只有主键 id**——表带 `uniqueKeys` 时（如 ReadingProgress / DailyHistory），重复插入会撞唯一约束（SqliteException 2067）。幂等写入用 **delete-then-insert** 或先查后插（user_data_repositories / daily_service 里的注释就是范例）。

## 8. 交接 Checklist

1. 读本文档 §4、§7（5 分钟）。
2. 推 CI 确认基线全绿（github_upload.ps1 → -Poll）。
3. 改数据 → 先看 §6 模板和 verified 约定；**宁可标待核对，不许编数值**。
4. 加功能 → QuickTools 函数 + 测试 + 注册三件套；UI 复用 calc_widgets/states。
5. 改库 → 三件套 + userTables + migration 测试。
6. 出包 → workflow 直推 apk-builds 分支取 APK；keystore-onetime artifact 若存在，先固化 Secrets。
7. 内容扩充路线：SOP/故障按工序补齐（过滤/灌装/包装还薄）、术语扩到 100+、书籍补 ferme_sop ch03+（过滤与灌装工序）。
