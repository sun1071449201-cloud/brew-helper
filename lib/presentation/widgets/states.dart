import 'package:flutter/material.dart';

/// 统一的加载态：居中进度圈 + 可选说明文字。
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.hint});

  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (hint != null) ...[
            const SizedBox(height: 12),
            Text(hint!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// 统一的空数据态：图标 + 标题 + 可选副标题/动作。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.outline),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

/// 列表项淡入动画：包裹任意卡片，首次出现时 220ms 上浮淡入。
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// “经验参考”角标：verified=false 的数据统一展示，提醒以本厂 SOP 为准。
class UnverifiedBadge extends StatelessWidget {
  const UnverifiedBadge({super.key, this.text = '经验参考'});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontSize: 10, color: scheme.onTertiaryContainer),
      ),
    );
  }
}
