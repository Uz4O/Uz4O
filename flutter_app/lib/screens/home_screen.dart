import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

class _HomeFeature {
  const _HomeFeature({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.bullets,
    required this.image,
    required this.icon,
    required this.imageWidth,
    required this.imageHeight,
    this.titleSize = 34,
    this.textWidth = 224,
  });

  final String title;
  final String subtitle;
  final String action;
  final List<String> bullets;
  final String image;
  final IconData icon;
  final double imageWidth;
  final double imageHeight;
  final double titleSize;
  final double textWidth;
}

class _BuildStyle {
  const _BuildStyle(this.title, this.cost, this.image);

  final String title;
  final String cost;
  final String image;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenFeature, this.onOpenStyle});

  final ValueChanged<int>? onOpenFeature;
  final ValueChanged<int>? onOpenStyle;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFeature = 0;

  static const _features = <_HomeFeature>[
    _HomeFeature(
      title: 'AI 一键装机',
      subtitle: '智能推荐装机方案',
      action: '开始装机',
      bullets: ['智能推荐配置', '自动检测兼容性', '优化预算方案'],
      image: 'assets/images/home_style_black_knight.png',
      icon: Icons.handyman_outlined,
      imageWidth: 167,
      imageHeight: 266,
      textWidth: 213,
    ),
    _HomeFeature(
      title: '游戏性能测试',
      subtitle: '检测游戏帧率表现',
      action: '开始测试',
      bullets: ['帧率表现评估', '硬件瓶颈分析', '游戏场景建议'],
      image: 'assets/images/home_hero_performance_gpu.png',
      icon: Icons.sports_esports_outlined,
      imageWidth: 220,
      imageHeight: 300,
      titleSize: 27,
      textWidth: 160,
    ),
    _HomeFeature(
      title: '配置排雷',
      subtitle: '判断配置能不能买',
      action: '开始排雷',
      bullets: ['识别搭配风险', '检查兼容问题', '提示预算浪费'],
      image: 'assets/images/home_hero_config_review_board.png',
      icon: Icons.verified_user_outlined,
      imageWidth: 146,
      imageHeight: 236,
      textWidth: 213,
    ),
    _HomeFeature(
      title: '升级建议',
      subtitle: '按预算给出升级顺序',
      action: '查看建议',
      bullets: ['定位升级短板', '排序更换优先级', '匹配预算方案'],
      image: 'assets/images/home_hero_upgrade_parts.png',
      icon: Icons.north_east_rounded,
      imageWidth: 162,
      imageHeight: 232,
      textWidth: 213,
    ),
  ];

  static const _styles = <_BuildStyle>[
    _BuildStyle(
      '联立 VISION COMPACT',
      '外观方案约 ¥2,735 起',
      'assets/images/style_vision_compact_black.webp',
    ),
    _BuildStyle(
      'ROG 创世神 701',
      '外观方案约 ¥3,476 起',
      'assets/images/style_rog_gr701_black.webp',
    ),
    _BuildStyle(
      '未知玩家 幻翼',
      '外观方案约 ¥1,257 起',
      'assets/images/style_phantom_wing_black.webp',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.homeBackground,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth - 34, 406.0);
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 112),
              child: Transform.translate(
                offset: const Offset(0, -3),
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'UzBox',
                            style: TextStyle(
                              fontFamily: '.SF Pro Display',
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _Hero(
                            key: ValueKey(_selectedFeature),
                            feature: _features[_selectedFeature],
                            onOpen: () =>
                                widget.onOpenFeature?.call(_selectedFeature),
                            onSwipe: (delta) {
                              setState(() {
                                _selectedFeature =
                                    (_selectedFeature + delta) %
                                    _features.length;
                                if (_selectedFeature < 0) {
                                  _selectedFeature += _features.length;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        _FeatureSelector(
                          selected: _selectedFeature,
                          onSelected: (index) =>
                              setState(() => _selectedFeature = index),
                        ),
                        const SizedBox(height: 34),
                        const Text(
                          '精选装机风格',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '找到你喜欢的主机外观与氛围',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.52),
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(_styles.length, (index) {
                          return Column(
                            children: [
                              _StyleRow(
                                style: _styles[index],
                                onTap: () => widget.onOpenStyle?.call(index),
                              ),
                              if (index != _styles.length - 1)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.black.withValues(alpha: 0.07),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    super.key,
    required this.feature,
    required this.onSwipe,
    required this.onOpen,
  });

  final _HomeFeature feature;
  final ValueChanged<int> onSwipe;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 120) onSwipe(velocity < 0 ? 1 : -1);
      },
      child: SizedBox(
        height: 316,
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 31,
              bottom: 20,
              width: feature.textWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前功能',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.50),
                      fontSize: 13,
                      height: 1.23,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      feature.title,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: feature.titleSize,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      feature.subtitle,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.70),
                        fontSize: 15,
                        height: 1.20,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ...feature.bullets.map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 13,
                            color: Colors.black.withValues(alpha: 0.48),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            bullet,
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.48),
                              fontSize: 13,
                              height: 1.23,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _HeroButton(title: feature.action, onTap: onOpen),
                ],
              ),
            ),
            Positioned(
              right: 6,
              top: 50,
              width: feature.imageWidth,
              height: feature.imageHeight,
              child: Image.asset(feature.image, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: Container(
        width: 136,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 18),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureSelector extends StatelessWidget {
  const _FeatureSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: List.generate(_HomeScreenState._features.length, (index) {
          final isSelected = index == selected;
          return Expanded(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isSelected ? 0.13 : 0.035,
                      ),
                      blurRadius: isSelected ? 16 : 8,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelected(index),
                    child: Icon(
                      _HomeScreenState._features[index].icon,
                      size: 24,
                      color: isSelected ? Colors.white : Colors.black,
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

class _StyleRow extends StatelessWidget {
  const _StyleRow({required this.style, required this.onTap});

  final _BuildStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    style.cost,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.72),
                      fontSize: 13,
                      height: 1.23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    '按这个风格装机  →',
                    style: TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(12, 0),
              child: SizedBox(
                width: 148,
                height: 106,
                child: Image.asset(style.image, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
