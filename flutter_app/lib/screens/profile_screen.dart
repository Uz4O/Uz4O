import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

class _ProfileItem {
  const _ProfileItem(
    this.title,
    this.icon, {
    this.subtitle,
    this.destructive = false,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final bool destructive;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onAction});

  final ValueChanged<String>? onAction;

  static const _buildItems = <_ProfileItem>[
    _ProfileItem('我的配置单', Icons.description_outlined, subtitle: '查看保存过的方案'),
  ];

  static const _helpItems = <_ProfileItem>[
    _ProfileItem('用户协议', Icons.description_outlined),
    _ProfileItem('隐私政策', Icons.lock_outline_rounded),
    _ProfileItem('第三方信息共享清单', Icons.layers_outlined),
    _ProfileItem('联系与投诉', Icons.send_outlined, subtitle: 'youz66811@gmail.com'),
  ];

  static const _destructiveItems = <_ProfileItem>[
    _ProfileItem(
      '注销账号',
      Icons.person_remove_outlined,
      subtitle: '永久删除账号及关联资料',
      destructive: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth - 56, 360.0);
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 18, bottom: 112),
              child: Center(
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Text(
                          '我的',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 18,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _ProfileHero(onTap: () => onAction?.call('电脑档案')),
                      const SizedBox(height: 20),
                      _ProfileSection(
                        title: '我的方案',
                        items: _buildItems,
                        onAction: onAction,
                      ),
                      const SizedBox(height: 20),
                      _ProfileSection(
                        title: '设置与帮助',
                        items: _helpItems,
                        onAction: onAction,
                      ),
                      const SizedBox(height: 20),
                      _ProfileSection(
                        items: _destructiveItems,
                        onAction: onAction,
                      ),
                    ],
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 41,
                  backgroundColor: Colors.black,
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 18),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 装机助手',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 21,
                          height: 1.19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '已填写 0/6 · 点击开始补充',
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.secondary,
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({this.title, required this.items, this.onAction});

  final String? title;
  final List<_ProfileItem> items;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              title!,
              style: const TextStyle(
                color: AppTheme.secondary,
                fontSize: 13,
                height: 1.23,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppTheme.cardShadow(),
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              return Column(
                children: [
                  _ProfileRow(
                    item: items[index],
                    onTap: () => onAction?.call(items[index].title),
                  ),
                  if (index != items.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 66, right: 18),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppTheme.border,
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.item, required this.onTap});

  final _ProfileItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = item.destructive
        ? AppTheme.destructive
        : AppTheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Center(
                  child: Icon(item.icon, color: foreground, size: 22),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        height: 1.27,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.secondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
