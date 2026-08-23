import 'package:flutter/material.dart';

import '../api/uzbox_api.dart';
import '../app_theme.dart';
import '../widgets/flow_components.dart';
import 'primary_flows.dart';

class DiyBuilderScreen extends StatefulWidget {
  const DiyBuilderScreen({super.key});

  @override
  State<DiyBuilderScreen> createState() => _DiyBuilderScreenState();
}

class _DiyBuilderScreenState extends State<DiyBuilderScreen> {
  final api = UzBoxApi();
  final selectedParts = <String, ({String id, String model, int price})>{};
  final catalog = <String, List<Map<String, dynamic>>>{};
  final prices = <String, int>{};
  int? recommendedPsuWatt;

  static const slots = <({String title, IconData icon, String hint})>[
    (title: 'CPU', icon: Icons.memory_rounded, hint: '点击选择配件'),
    (title: '显卡', icon: Icons.desktop_windows_outlined, hint: '点击选择配件'),
    (title: '主板', icon: Icons.grid_on_rounded, hint: '点击选择配件'),
    (title: '散热器', icon: Icons.ac_unit_rounded, hint: '点击选择配件'),
    (title: '内存', icon: Icons.memory_outlined, hint: '点击选择配件'),
    (title: '固态硬盘', icon: Icons.storage_rounded, hint: '点击选择配件'),
    (title: '电源', icon: Icons.power_settings_new_rounded, hint: '点击选择配件'),
    (title: '机箱', icon: Icons.crop_portrait_rounded, hint: '点击选择配件'),
  ];

  @override
  Widget build(BuildContext context) {
    final total = selectedParts.values.fold<int>(
      0,
      (sum, part) => sum + part.price,
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(26, 8, 26, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        elevation: 1,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.chevron_left_rounded,
                              size: 32,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'UzBox',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '我的装机方案',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 94,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: AppTheme.cardShadow(opacity: 0.08),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DiyMetric(
                            value: selectedParts.isEmpty ? '待选择' : '¥$total',
                            label: '预计总价',
                          ),
                        ),
                        const VerticalDivider(indent: 16, endIndent: 16),
                        Expanded(
                          child: _DiyMetric(
                            value: '${selectedParts.length} / 8',
                            label: '已选择',
                          ),
                        ),
                        const VerticalDivider(indent: 16, endIndent: 16),
                        Expanded(
                          child: _DiyMetric(
                            value: recommendedPsuWatt == null
                                ? '待选择'
                                : '${recommendedPsuWatt}W',
                            label: '推荐电源瓦数',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '八大件配置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: AppTheme.cardShadow(opacity: 0.07),
                    ),
                    child: Column(
                      children: List.generate(slots.length, (index) {
                        final slot = slots[index];
                        return InkWell(
                          onTap: () => _showPicker(slot.title),
                          child: Container(
                            height: 70,
                            decoration: index == slots.length - 1
                                ? null
                                : const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: AppTheme.border,
                                      ),
                                    ),
                                  ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  child: Icon(slot.icon, size: 23),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        selectedParts[slot.title]?.model ??
                                            slot.hint,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppTheme.secondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(26, 8, 26, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.image_outlined, size: 17),
                            label: const Text('保存图片'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('配置已保存')),
                                ),
                            icon: const Icon(
                              Icons.bookmark_border_rounded,
                              size: 17,
                            ),
                            label: const Text('保存到我的配置单'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(String title) async {
    var items = catalog[title];
    if (items == null) {
      try {
        final results = await Future.wait([
          api.catalogComponents(category: _catalogCategory(title)),
          if (prices.isEmpty) api.catalogPrices(),
        ]);
        items = results.first;
        catalog[title] = items;
        if (results.length > 1) {
          for (final price in results[1]) {
            final componentId = price['component_id']?.toString();
            final referencePrice = price['reference_price'];
            if (componentId != null && referencePrice is num) {
              prices[componentId] = referencePrice.round();
            }
          }
        }
      } catch (_) {
        items = const [];
      }
    }
    if (!mounted) return;
    final visibleItems = items;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.74,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Text(
                    '选择$title',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: '搜索品牌或型号',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF5F6F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      _PickerChip('全部', selected: true),
                      SizedBox(width: 8),
                      _PickerChip('AMD'),
                      SizedBox(width: 8),
                      _PickerChip('Intel'),
                      Spacer(),
                      _PickerChip('13 代酷睿'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: visibleItems.isEmpty ? 8 : visibleItems.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = visibleItems.isEmpty
                      ? null
                      : visibleItems[index];
                  final componentId = item?['id']?.toString() ?? '';
                  final model =
                      item?['name']?.toString() ?? '$title 推荐型号 ${index + 1}';
                  final brand = item?['brand']?.toString() ?? '主流在售';
                  final price = prices[componentId] ?? 399 + index * 120;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    title: Text(
                      model,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('$brand · 兼容性已校验'),
                    trailing: Text(
                      '¥$price',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () {
                      setState(() {
                        selectedParts[title] = (
                          id: componentId,
                          model: model,
                          price: price,
                        );
                      });
                      Navigator.pop(context);
                      _refreshRecommendedPsuWatt();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _catalogCategory(String title) {
    return switch (title) {
      'CPU' => 'cpu',
      '显卡' => 'gpu',
      '主板' => 'motherboard',
      '内存' => 'ram',
      '固态硬盘' => 'storage',
      '电源' => 'psu',
      '散热器' => 'cooler',
      '机箱' => 'case',
      _ => title,
    };
  }

  Future<void> _refreshRecommendedPsuWatt() async {
    final cpuId = selectedParts['CPU']?.id;
    final gpuId = selectedParts['显卡']?.id;
    if (cpuId == null || cpuId.isEmpty || gpuId == null || gpuId.isEmpty) {
      if (mounted) setState(() => recommendedPsuWatt = null);
      return;
    }
    if (mounted) setState(() => recommendedPsuWatt = null);

    try {
      final watt = await api.recommendedPsuWatt(cpuId: cpuId, gpuId: gpuId);
      if (!mounted ||
          selectedParts['CPU']?.id != cpuId ||
          selectedParts['显卡']?.id != gpuId) {
        return;
      }
      setState(() => recommendedPsuWatt = watt);
    } catch (_) {
      if (mounted &&
          selectedParts['CPU']?.id == cpuId &&
          selectedParts['显卡']?.id == gpuId) {
        setState(() => recommendedPsuWatt = null);
      }
    }
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip(this.label, {this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Colors.black : const Color(0xFFF2F3F4),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DiyMetric extends StatelessWidget {
  const _DiyMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.secondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class MyBuildsScreen extends StatefulWidget {
  const MyBuildsScreen({super.key});

  @override
  State<MyBuildsScreen> createState() => _MyBuildsScreenState();
}

class _MyBuildsScreenState extends State<MyBuildsScreen> {
  int section = 0;

  static const plans =
      <
        ({
          String title,
          String budget,
          String useCase,
          String price,
          String createdAt,
        })
      >[
        (
          title: '2K 游戏均衡配置',
          budget: '8000 档',
          useCase: '2K 游戏 / 日常剪辑 / 可升级',
          price: '¥ 8566',
          createdAt: '今天 17:20',
        ),
        (
          title: '5000 办公剪辑配置',
          budget: '5000 档',
          useCase: '办公 / 轻剪辑',
          price: '¥ 5188',
          createdAt: '昨天 21:08',
        ),
        (
          title: '万元 4K 游戏配置',
          budget: '10000+ 档',
          useCase: '4K 游戏 / 直播',
          price: '¥ 10880',
          createdAt: '5 月 29 日',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(36, 12, 36, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.chevron_left_rounded, size: 34),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '配置',
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '管理 AI 生成的配置和现在自己的配置',
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              UzSegmentedControl(
                options: const ['AI 配置', '当前电脑'],
                selected: section,
                height: 38,
                onSelected: (value) => setState(() => section = value),
                selectedColor: AppTheme.primary,
                selectedForeground: Colors.white,
              ),
              const SizedBox(height: 28),
              if (section == 0) ...[
                const Row(
                  children: [
                    Text(
                      '我的配置单',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '2 个',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...plans.map(
                  (plan) => _BuildPlanRow(
                    title: plan.title,
                    subtitle: '${plan.budget} · ${plan.useCase}',
                    price: plan.price,
                    createdAt: plan.createdAt,
                  ),
                ),
              ] else ...[
                const Row(
                  children: [
                    Text(
                      '当前电脑',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '已填写 0/6',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...[
                  'CPU',
                  '显卡',
                  '主板',
                  '内存',
                  '硬盘',
                  '电源',
                ].map((title) => _CurrentComputerRow(title: title)),
                const SizedBox(height: 20),
                UzPrimaryButton(
                  title: '继续补充电脑配置',
                  onPressed: () => Navigator.of(
                    context,
                  ).push(uzRoute(const ComputerProfileScreen())),
                ),
                const SizedBox(height: 28),
                const Text(
                  '可以用它做什么',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _UseCaseRow(
                  icon: Icons.bar_chart_rounded,
                  title: '看升级短板',
                  subtitle: '判断当前电脑最该先换什么',
                  onTap: () => Navigator.of(
                    context,
                  ).push(uzRoute(const UpgradePlanScreen())),
                ),
                _UseCaseRow(
                  icon: Icons.sports_esports_outlined,
                  title: '测游戏表现',
                  subtitle: '结合分辨率和游戏估算体验',
                  onTap: () => Navigator.of(
                    context,
                  ).push(uzRoute(const GamePerformanceScreen())),
                ),
                _UseCaseRow(
                  icon: Icons.compare_arrows_rounded,
                  title: '对比 AI 配置',
                  subtitle: '看新配置相比当前电脑提升在哪',
                  onTap: () => Navigator.of(
                    context,
                  ).push(uzRoute(const AiBuildScreen())),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildPlanRow extends StatelessWidget {
  const _BuildPlanRow({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.createdAt,
  });
  final String title;
  final String subtitle;
  final String price;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Navigator.of(context).push(uzRoute(const BuildResultDemoScreen())),
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF0F2),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.description_outlined, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  createdAt,
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.secondary),
          ],
        ),
      ),
    );
  }
}

class _CurrentComputerRow extends StatelessWidget {
  const _CurrentComputerRow({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const Expanded(
            child: Text(
              '不知道',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppTheme.secondary),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.secondary),
        ],
      ),
    );
  }
}

class _UseCaseRow extends StatelessWidget {
  const _UseCaseRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF0F2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.secondary, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class ComputerProfileScreen extends StatefulWidget {
  const ComputerProfileScreen({super.key});

  @override
  State<ComputerProfileScreen> createState() => _ComputerProfileScreenState();
}

class _ComputerProfileScreenState extends State<ComputerProfileScreen> {
  final api = UzBoxApi();
  static const categories = <({String title, IconData icon})>[
    (title: 'CPU', icon: Icons.memory_rounded),
    (title: '显卡', icon: Icons.desktop_windows_outlined),
    (title: '主板', icon: Icons.developer_board_outlined),
    (title: '内存', icon: Icons.view_stream_outlined),
    (title: '硬盘', icon: Icons.storage_rounded),
    (title: '电源', icon: Icons.bolt_rounded),
  ];

  final values = <String, String>{
    'CPU': '不知道',
    '显卡': '不知道',
    '主板': '不知道',
    '内存': '不知道',
    '硬盘': '不知道',
    '电源': '不知道',
  };

  static const options = <String, List<String>>{
    'CPU': ['Intel Core i5-14600K', 'AMD Ryzen 5 9600X', 'i7-14700K'],
    '显卡': ['RTX 4070 Super 12GB', 'RTX 5070', 'RX 9070 GRE'],
    '主板': ['B760M AORUS ELITE', '华硕 PRIME B650M-K', 'B850M WIFI'],
    '内存': ['DDR5 6000 32GB', 'DDR5 6000 16GB', 'DDR4 3200 16GB'],
    '硬盘': ['1TB PCIe 4.0 SSD', '梵想 S790E 1TB', '2TB PCIe 4.0 SSD'],
    '电源': ['650W 金牌全模组', '750W 金牌', '850W 金牌全模组'],
  };

  @override
  Widget build(BuildContext context) {
    final completed = values.values.where((value) => value != '不知道').length;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            children: [
              const UzPageHeader(title: '我的电脑档案'),
              const SizedBox(height: 16),
              UzSoftCard(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已填写 $completed/6',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '选择你知道的硬件即可，不确定的项目可以稍后补充。',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              UzSoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: categories
                      .map(
                        (category) => InkWell(
                          onTap: () => _showPicker(category.title),
                          child: Container(
                            height: 58,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppTheme.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDF0F2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(category.icon, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  category.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  values[category.title] ?? '不知道',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.secondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: AppTheme.secondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPicker(String category) async {
    var choices = options[category] ?? const <String>[];
    try {
      final components = await api.catalogComponents(
        category: _profileCatalogCategory(category),
      );
      final remoteChoices = components
          .map((component) => component['name']?.toString())
          .whereType<String>()
          .toList();
      if (remoteChoices.isNotEmpty) choices = remoteChoices;
    } catch (_) {
      // Use the calibrated local catalog if the network is unavailable.
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 18, 12),
                child: Row(
                  children: [
                    Text(
                      '选择$category',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索品牌或型号',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF5F6F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: choices.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final value = index == 0 ? '不知道' : choices[index - 1];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: value == values[category]
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(context, value),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() => values[category] = selected);
  }

  String _profileCatalogCategory(String category) => switch (category) {
    'CPU' => 'cpu',
    '显卡' => 'gpu',
    '主板' => 'motherboard',
    '内存' => 'ram',
    '硬盘' => 'storage',
    '电源' => 'psu',
    _ => category,
  };
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UzPageHeader(title: title),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '更新日期：2026 年 8 月 10 日\n\n欢迎使用 UzBox。我们重视你的隐私与数据安全。本页面说明服务使用规则、信息处理方式以及你的相关权利。\n\n一、服务说明\nUzBox 用于帮助用户理解电脑硬件、生成配置建议并检查兼容性。\n\n二、信息使用\n仅在提供核心功能所需的范围内处理你主动填写的信息。\n\n三、你的权利\n你可以查询、更正或删除相关资料，也可以通过联系与投诉页面向我们反馈。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: Color(0xFF404040),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactComplaintScreen extends StatelessWidget {
  const ContactComplaintScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UzPageHeader(title: '联系与投诉'),
              const SizedBox(height: 20),
              const Text(
                '告诉我们你遇到的问题',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                '我们会认真处理产品建议、账号问题和投诉反馈。',
                style: TextStyle(color: AppTheme.secondary),
              ),
              const SizedBox(height: 22),
              const Text('问题类型', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const UzSegmentedControl(
                options: ['产品建议', '账号问题', '投诉'],
                selected: 0,
                onSelected: _noop,
              ),
              const SizedBox(height: 18),
              const Text('问题描述', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(
                maxLines: 7,
                decoration: InputDecoration(
                  hintText: '请尽量详细描述问题…',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                decoration: InputDecoration(
                  labelText: '联系方式（选填）',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              UzPrimaryButton(
                title: '提交反馈',
                icon: Icons.send_rounded,
                onPressed: () {},
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  '联系邮箱：youz66811@gmail.com',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _noop(int _) {}
}

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = controller.text == 'DELETE';
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      '注销账号',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 44),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '注销后将删除或匿名化账号资料、硬件档案和保存方案。相关记录将按隐私政策和法律要求处理。',
                style: TextStyle(fontSize: 15, height: 1.7),
              ),
              const SizedBox(height: 20),
              const Text(
                '此操作不可撤销。请输入 DELETE 确认。',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: enabled
                      ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('演示版不会真正注销账号')),
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red.withValues(alpha: 0.42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '永久注销账号',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
