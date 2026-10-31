# brew_helper — 啤酒酿造车间助手

面向啤酒酿造车间一线操作员的离线学习工具。车间里遇到工艺异常时快速查 SOP、查计算公式、查故障排查步骤；平时用学习卡和术语库巩固知识。**完全离线，不联网。**

> ⚠ 数据红线：App 内所有工艺参数均为**经验参考值**（`verified=false`），执行前一律以本厂现行 SOP / 工艺卡为准。App 只负责讲清楚"为什么"和"现场怎么检查"。

## 功能

| Tab | 内容 |
|---|---|
| SOP 查询 | 按工序分类（糖化/发酵/CIP/过滤/灌装/包装）+ 全文搜索，详情可收藏、划词查术语 |
| 工艺计算器 | 8 个现场计算器：比重换算、酒精度、IBU、补糖、清洗剂配比、单位换算、热水用量、CO2 对照 |
| 异常排查 | 按症状搜索：症状 → 可能原因 → 排查步骤 → 对策 |
| 酿造术语 | 中英双语酿造词库 + 背诵翻卡模式 |

另有：**安全红线页**（CO2/碱液/密闭空间/热烫伤/氨/爆瓶）、**3 本酿造手册**（SOP / 异常排查 / 术语与计算，带书签与阅读进度）。

## 构建

本项目**不含 android/ 壳工程**，由 GitHub Actions 现场生成（Flutter 3.24.0 + JDK 17）：

- 推送到 main 自动构建；产物直推 `apk-builds` 分支。
- 本地有 Flutter SDK 时：`flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter test && flutter analyze && flutter build apk --release --split-per-abi`。

## 文档

- 给下一个接手的 AI / 开发者：[README_FOR_AI.md](README_FOR_AI.md)
- 更新日志：[CHANGELOG.md](CHANGELOG.md)

## 隐私

不联网、不采集、不上传。书签/进度/设置只存在本机数据库。
