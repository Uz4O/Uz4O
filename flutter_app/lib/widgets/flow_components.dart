import 'package:flutter/material.dart';

import '../app_theme.dart';

class UzPageHeader extends StatelessWidget {
  const UzPageHeader({
    super.key,
    required this.title,
    this.trailing,
    this.centerTitle = true,
  });

  final String title;
  final Widget? trailing;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: const Icon(
                Icons.chevron_left_rounded,
                size: 36,
                color: AppTheme.primary,
              ),
            ),
          ),
          Align(
            alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: centerTitle ? 0 : 52),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

class UzSoftCard extends StatelessWidget {
  const UzSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: AppTheme.cardShadow(opacity: 0.065),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

class UzPrimaryButton extends StatelessWidget {
  const UzPrimaryButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.outlined = false,
    this.height = 52,
    this.icon = Icons.arrow_forward_rounded,
    this.backgroundColor = Colors.black,
  });

  final String title;
  final VoidCallback? onPressed;
  final bool outlined;
  final double height;
  final IconData icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final foreground = outlined ? Colors.black : Colors.white;
    return Material(
      color: onPressed == null
          ? backgroundColor.withValues(alpha: 0.55)
          : outlined
          ? Colors.white
          : backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: outlined
            ? const BorderSide(color: Colors.black, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: foreground, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class UzSegmentedControl extends StatelessWidget {
  const UzSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.height = 48,
    this.showsSelectionDot = false,
    this.selectedColor = Colors.white,
    this.selectedForeground = AppTheme.primary,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;
  final double height;
  final bool showsSelectionDot;
  final Color selectedColor;
  final Color selectedForeground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: const Color(0xFFE5E9ED)),
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          final active = selected == index;
          return Expanded(
            child: AnimatedScale(
              scale: active ? 1 : 0.985,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: active ? selectedColor : Colors.transparent,
                  borderRadius: BorderRadius.circular((height - 8) / 2),
                  border: active
                      ? Border.all(
                          color: selectedColor.computeLuminance() < 0.5
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.96),
                        )
                      : null,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: selectedColor.computeLuminance() < 0.5
                                  ? 0.18
                                  : 0.08,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const [],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular((height - 8) / 2),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    borderRadius: BorderRadius.circular((height - 8) / 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showsSelectionDot) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: active
                                  ? selectedForeground
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: active
                                  ? null
                                  : Border.all(
                                      color: AppTheme.secondary,
                                      width: 1.2,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              color: active
                                  ? selectedForeground
                                  : AppTheme.secondary,
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                            child: Text(
                              options[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class UzBottomAction extends StatelessWidget {
  const UzBottomAction({
    super.key,
    required this.title,
    required this.onPressed,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final VoidCallback onPressed;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                onPressed: showBack ? onBack : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: AppTheme.border),
                  disabledForegroundColor: AppTheme.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Icon(Icons.chevron_left_rounded, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: UzPrimaryButton(
                title: title,
                onPressed: onPressed,
                height: 48,
                backgroundColor: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Route<void> uzRoute(Widget page, {bool fullscreenDialog = false}) {
  return PageRouteBuilder<void>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.035, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
