import 'dart:math' as math;

import 'package:flutter/material.dart';

class _Capability {
  const _Capability(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}

class DiyScreen extends StatelessWidget {
  const DiyScreen({super.key, this.onStartDiy});

  final VoidCallback? onStartDiy;

  static const _capabilities = <_Capability>[
    _Capability('总价实时统计', '所选配件总价实时更新', Icons.currency_yen_rounded),
    _Capability('功耗估算', '整机功耗预估', Icons.bolt_rounded),
    _Capability('兼容性检测', '自动检测硬件兼容性问题', Icons.verified_user_outlined),
    _Capability('瓶颈分析', '分析整机性能短板与平衡性', Icons.bar_chart_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 440.0);
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 110),
              child: Center(
                child: SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 44,
                          child: Text(
                            'UzBox',
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        _DiyHero(onStartDiy: onStartDiy),
                        const SizedBox(height: 52),
                        const Text(
                          'DIY 能做什么',
                          style: TextStyle(
                            fontSize: 21.5,
                            height: 1.26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _capabilities.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 84,
                              ),
                          itemBuilder: (context, index) =>
                              _CapabilityCard(capability: _capabilities[index]),
                        ),
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

class _DiyHero extends StatelessWidget {
  const _DiyHero({required this.onStartDiy});

  final VoidCallback? onStartDiy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 389,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            bottom: 10,
            width: 250,
            height: 270,
            child: Image.asset(
              'assets/images/diy_entry_hero.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 0,
            top: 54,
            width: 255,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前功能',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.50),
                    fontSize: 13,
                    height: 1.23,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DIY 自由选配',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 41,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '自己选硬件，App 帮你实时检查\n兼容性和预算',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.62),
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                const _HeroCheck('智能统计总价'),
                const SizedBox(height: 12),
                const _HeroCheck('自动检测兼容性'),
                const SizedBox(height: 12),
                const _HeroCheck('AI 给出优化建议'),
                const SizedBox(height: 24),
                Container(
                  width: 144,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: onStartDiy,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '开始 DIY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 18),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCheck extends StatelessWidget {
  const _HeroCheck(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 14,
          color: Colors.black.withValues(alpha: 0.49),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.49),
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability});

  final _Capability capability;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.035)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Icon(capability.icon, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    capability.title,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    capability.subtitle,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.48),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
