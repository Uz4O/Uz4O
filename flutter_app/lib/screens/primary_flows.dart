import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/uzbox_api.dart';
import '../app_theme.dart';
import '../widgets/flow_components.dart';

class AiBuildScreen extends StatefulWidget {
  const AiBuildScreen({super.key});

  @override
  State<AiBuildScreen> createState() => _AiBuildScreenState();
}

class _AiBuildScreenState extends State<AiBuildScreen> {
  int step = 0;
  double budget = 6850;
  int purpose = 0;
  bool ownedGpu = false;
  bool wireless = false;
  int buildPreference = 2;
  int colorPreference = 0;
  int upgradePreference = 0;
  int memoryPreference = 0;
  int storagePreference = 1;
  final selectedGames = <int>{};

  static const steps = ['预算和用途', '场景选择', '购买和外观', '补充偏好'];
  static const games = <({String title, String asset})>[
    (title: '什么都玩', asset: 'assets/images/game_pubg.png'),
    (title: '瓦罗兰特', asset: 'assets/images/game_valorant.png'),
    (title: 'CS2', asset: 'assets/images/game_cs2.png'),
    (title: 'PUBG', asset: 'assets/images/game_pubg.png'),
    (title: '三角洲行动', asset: 'assets/images/game_delta_force.png'),
    (title: '云顶之弈', asset: 'assets/images/game_tft.png'),
    (title: 'LOL', asset: 'assets/images/game_lol.png'),
    (title: 'COD', asset: 'assets/images/game_cod.png'),
    (title: '赛博朋克2077', asset: 'assets/images/game_cyberpunk.png'),
    (title: '荒野大镖客2', asset: 'assets/images/game_rdr2.png'),
    (title: 'GTA5', asset: 'assets/images/game_gta5.png'),
    (title: '黑神话悟空', asset: 'assets/images/game_wukong.png'),
    (title: '地平线6', asset: 'assets/images/game_forza.png'),
    (title: '艾尔登法环', asset: 'assets/images/game_elden_ring.png'),
    (title: '城市天际线', asset: 'assets/images/game_cities.png'),
    (title: '我的世界', asset: 'assets/images/game_minecraft.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
              child: Column(
                children: [
                  const _AiPageHeader(),
                  const SizedBox(height: 16),
                  _StepHeader(step: step, titles: steps),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 78,
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        '第 ${step + 1}/4 步',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _stepContent(),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: UzBottomAction(
                title: step == 3 ? '生成配置方案' : '下一步',
                showBack: step > 0,
                onBack: () => setState(() => step -= 1),
                onPressed: () {
                  if (step < 3) {
                    setState(() => step += 1);
                  } else {
                    Navigator.of(context).push(
                      uzRoute(
                        AiGeneratingScreen(
                          budget: budget.round(),
                          useCase: const ['游戏', '办公', '游戏兼办公'][purpose],
                          gameCategories: selectedGames
                              .map((index) => games[index].title)
                              .toList(),
                          direction: const [
                            'fps',
                            'aaa',
                            'balanced',
                          ][buildPreference],
                          needsWirelessNetwork: wireless,
                          memorySize: memoryPreference == 0 ? '16GB' : '32GB',
                          storageSize: const [
                            '512GB',
                            '1TB',
                            '2TB',
                          ][storagePreference],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent() {
    if (step == 0) {
      return UzSoftCard(
        key: const ValueKey(0),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '预算和用途',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            const Text(
              '先确定大方向，AI 会按预算控制配置。',
              style: TextStyle(color: AppTheme.secondary, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  '预算范围',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '¥ ${budget.round()}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Text(
                  '¥ 3000',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 11),
                ),
                Spacer(),
                Text(
                  '¥ 30000',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _RoundStepButton(
                  icon: Icons.remove_rounded,
                  onTap: () => setState(
                    () => budget = (budget - 500).clamp(3000, 30000),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.primary,
                        inactiveTrackColor: const Color(0xFFE1E4E7),
                        thumbColor: Colors.white,
                        trackHeight: 5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 16,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Slider(
                        min: 3000,
                        max: 30000,
                        value: budget,
                        onChanged: (value) => setState(() => budget = value),
                      ),
                    ),
                  ),
                ),
                _RoundStepButton(
                  icon: Icons.add_rounded,
                  onTap: () => setState(
                    () => budget = (budget + 500).clamp(3000, 30000),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              '主要用途',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            UzSegmentedControl(
              options: const ['游戏', '办公', '游戏兼办公'],
              selected: purpose,
              onSelected: (value) => setState(() => purpose = value),
              selectedColor: AppTheme.primary,
              selectedForeground: Colors.white,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '无显卡方案',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '是否自备显卡',
                        style: TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: Switch.adaptive(
                    value: ownedGpu,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (value) => setState(() => ownedGpu = value),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (step == 1) {
      return Column(
        key: const ValueKey(1),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择你常玩的游戏',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            '可多选，AI 会按游戏需求调整配置',
            style: TextStyle(color: AppTheme.secondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            '全部游戏',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: games.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final selected = selectedGames.contains(index);
              final game = games[index];
              return InkWell(
                onTap: () => setState(() {
                  selected
                      ? selectedGames.remove(index)
                      : selectedGames.add(index);
                }),
                borderRadius: BorderRadius.circular(13),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: index == 0
                                  ? const _AllGamesArtwork()
                                  : Image.asset(game.asset, fit: BoxFit.cover),
                            ),
                          ),
                          if (selected)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      game.title,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );
    }

    return UzSoftCard(
      key: ValueKey(step),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: step == 2
            ? [
                const Text(
                  '购买和外观',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                const Text(
                  '选择你能接受的购买方式和主机外观。',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 14),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '无线网络',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '房间没有墙上网口时建议打开',
                            style: TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: wireless,
                      activeTrackColor: Colors.black,
                      onChanged: (value) => setState(() => wireless = value),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _aiPreferenceGroup(
                  '装机偏好',
                  const ['性能优先', '颜值优先', '均衡搭配'],
                  buildPreference,
                  (value) => setState(() => buildPreference = value),
                ),
                const SizedBox(height: 18),
                _aiPreferenceGroup(
                  '主机颜色偏好',
                  const ['曜石黑', '纯净白'],
                  colorPreference,
                  (value) => setState(() => colorPreference = value),
                  showsSelectionDot: true,
                ),
              ]
            : [
                const Text(
                  '补充偏好',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                const Text(
                  '再补充一个会影响配置取舍的问题。',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 14),
                ),
                const SizedBox(height: 18),
                _aiPreferenceGroup(
                  '后期升级计划',
                  const ['当前体验优先', '保留升级空间'],
                  upgradePreference,
                  (value) => setState(() => upgradePreference = value),
                ),
                const SizedBox(height: 18),
                if (budget >= 6500 && budget < 8000)
                  _aiPreferenceGroup(
                    '容量优先（二选一）',
                    const ['32GB 内存', '1TB 固态'],
                    memoryPreference == 1 ? 0 : 1,
                    (value) =>
                        setState(() => memoryPreference = value == 0 ? 1 : 0),
                  )
                else ...[
                  _aiPreferenceGroup(
                    '内存大小',
                    const ['16GB', '32GB'],
                    memoryPreference,
                    (value) => setState(() => memoryPreference = value),
                  ),
                  const SizedBox(height: 18),
                  _aiPreferenceGroup(
                    '存储大小',
                    const ['512GB', '1TB', '2TB'],
                    storagePreference,
                    (value) => setState(() => storagePreference = value),
                  ),
                ],
              ],
      ),
    );
  }

  Widget _aiPreferenceGroup(
    String title,
    List<String> options,
    int selected,
    ValueChanged<int> onSelected, {
    bool showsSelectionDot = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        UzSegmentedControl(
          options: options,
          selected: selected,
          onSelected: onSelected,
          showsSelectionDot: showsSelectionDot,
        ),
      ],
    );
  }
}

class _AllGamesArtwork extends StatelessWidget {
  const _AllGamesArtwork();

  @override
  Widget build(BuildContext context) {
    const assets = [
      'assets/images/game_pubg.png',
      'assets/images/game_valorant.png',
      'assets/images/game_wukong.png',
      'assets/images/game_cyberpunk.png',
    ];
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      children: assets
          .map((asset) => Image.asset(asset, fit: BoxFit.cover))
          .toList(),
    );
  }
}

class _AiPageHeader extends StatelessWidget {
  const _AiPageHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'AI 写配置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(titles.length * 2 - 1, (index) {
        if (index.isOdd) {
          final completed = index ~/ 2 < step;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(top: 20, left: 8, right: 8),
              color: completed ? AppTheme.primary : const Color(0xFFE2E6EA),
            ),
          );
        }
        final item = index ~/ 2;
        final active = item == step;
        final completed = item < step;
        return SizedBox(
          width: 66,
          child: Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active || completed ? AppTheme.primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active || completed
                        ? AppTheme.primary
                        : AppTheme.border,
                  ),
                ),
                child: completed
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 15,
                      )
                    : Text(
                        '${item + 1}',
                        style: TextStyle(
                          color: active ? Colors.white : AppTheme.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                titles[item],
                maxLines: 1,
                style: TextStyle(
                  color: active ? AppTheme.primary : AppTheme.secondary,
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: AppTheme.border),
          shape: const CircleBorder(),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
    );
  }
}

class AiGeneratingScreen extends StatefulWidget {
  const AiGeneratingScreen({
    super.key,
    this.budget = 6850,
    this.useCase = '游戏',
    this.gameCategories = const ['什么都玩'],
    this.direction = 'balanced',
    this.needsWirelessNetwork = false,
    this.memorySize = '16GB',
    this.storageSize = '1TB',
  });

  final int budget;
  final String useCase;
  final List<String> gameCategories;
  final String direction;
  final bool needsWirelessNetwork;
  final String memorySize;
  final String storageSize;

  @override
  State<AiGeneratingScreen> createState() => _AiGeneratingScreenState();
}

class _AiGeneratingScreenState extends State<AiGeneratingScreen> {
  int progress = 3;
  Timer? progressTimer;
  final api = UzBoxApi();

  @override
  void initState() {
    super.initState();
    progressTimer = Timer.periodic(const Duration(milliseconds: 140), (timer) {
      if (!mounted || progress >= 99) return;
      setState(() => progress += 1);
    });
    unawaited(_generate());
  }

  Future<void> _generate() async {
    Map<String, dynamic>? response;
    final request = api
        .buildOptions(
          budget: widget.budget,
          useCase: widget.useCase,
          gameCategories: widget.gameCategories,
          direction: widget.direction,
          needsWirelessNetwork: widget.needsWirelessNetwork,
          memorySize: widget.memorySize,
          storageSize: widget.storageSize,
        )
        .then((value) => response = value)
        .catchError((Object _) => <String, dynamic>{});
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      Future.any([request, Future.delayed(const Duration(milliseconds: 6000))]),
    ]);
    if (!mounted) return;
    progressTimer?.cancel();
    setState(() => progress = 100);
    await Navigator.of(
      context,
    ).pushReplacement(uzRoute(BuildOptionsDemoScreen(response: response)));
  }

  @override
  void dispose() {
    progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'UzBox',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'AI 正在生成配置单',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '正在根据你的需求匹配更适合的硬件方案',
                    style: TextStyle(color: Color(0xFF8C8C8C), fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  _GenerationDial(progress: progress),
                  const SizedBox(height: 8),
                  _GenerationTimeline(progress: progress),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  '通常需要几秒钟，请稍候',
                  style: TextStyle(color: Color(0xFF999999), fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationDial extends StatelessWidget {
  const _GenerationDial({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 342,
      height: 330,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(304),
            painter: _GenerationDialPainter(progress / 100),
          ),
          Image.asset(
            'assets/images/pc_tower.png',
            width: 184,
            height: 184,
            fit: BoxFit.contain,
            color: Colors.white.withValues(alpha: 0.10),
            colorBlendMode: BlendMode.screen,
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 94,
              height: 94,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$progress',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const TextSpan(
                          text: '%',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    '生成中',
                    style: TextStyle(color: Color(0xFF898989), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationDialPainter extends CustomPainter {
  const _GenerationDialPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 23;
    final faint = Paint()
      ..color = Colors.black.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius, faint);

    final ticks = Paint()
      ..color = Colors.black.withValues(alpha: 0.075)
      ..strokeWidth = 1;
    for (var index = 0; index < 96; index++) {
      final angle = index / 96 * math.pi * 2 - math.pi / 2;
      final outer = radius + 20;
      final inner = outer - (index.isEven ? 8 : 5);
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        ticks,
      );
    }

    final arc = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _GenerationDialPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GenerationTimeline extends StatelessWidget {
  const _GenerationTimeline({required this.progress});
  final int progress;

  static const stages = ['分析需求', '检查兼容性', '优化配置方案', '生成最终结果'];

  @override
  Widget build(BuildContext context) {
    final current = math.min(3, progress ~/ 25);
    return SizedBox(
      width: 300,
      child: Column(
        children: List.generate(stages.length, (index) {
          final active = index <= current;
          return SizedBox(
            height: 54,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 42,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      if (index < stages.length - 1)
                        Positioned(
                          top: 11,
                          bottom: -1,
                          child: Container(
                            width: 1,
                            color: const Color(0xFFD3D3D3),
                          ),
                        ),
                      Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          color: active ? Colors.black : Colors.white,
                          shape: BoxShape.circle,
                          border: active
                              ? null
                              : Border.all(
                                  color: const Color(0xFFBEBEBE),
                                  width: 1.5,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}.  ${stages[index]}',
                        style: TextStyle(
                          color: index > current
                              ? const Color(0xFFB2B2B2)
                              : Colors.black,
                          fontSize: 16,
                          fontWeight: index == current
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      if (index < stages.length - 1)
                        Container(
                          width: 120,
                          height: 1,
                          margin: const EdgeInsets.only(top: 14),
                          color: const Color(0xFFE8E8E8),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class BuildOptionsDemoScreen extends StatelessWidget {
  const BuildOptionsDemoScreen({super.key, this.response});

  final Map<String, dynamic>? response;

  static const options = [
    ('二手方案', '二手', 'R5 9600X + RTX 4070', '¥ 6,800'),
    ('全新方案', '全新', 'i5-12600KF + RX 9070 GRE', '¥ 7,327'),
    ('混合采购方案', '混合', 'i5-12600KF + RTX 4070', '¥ 6,597'),
  ];

  @override
  Widget build(BuildContext context) {
    final apiOptions = (response?['options'] as List? ?? const <Object>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    final visibleOptions = apiOptions.isEmpty
        ? options
              .map(
                (option) => (
                  title: option.$1,
                  badge: option.$2,
                  detail: option.$3,
                  price: option.$4,
                  raw: null as Map<String, dynamic>?,
                ),
              )
              .toList()
        : apiOptions.map((option) {
            final details = option['details'] as Map<String, dynamic>?;
            final parts = (details?['parts'] as List? ?? const <Object>[])
                .whereType<Map<String, dynamic>>()
                .toList();
            final mode = details?['purchase_mode']?.toString();
            final badge = switch (mode) {
              'new' => '全新',
              'mixed' => '混合',
              _ => '二手',
            };
            final cpu = parts
                .where((part) => part['role'] == 'cpu')
                .map((part) => part['name']?.toString())
                .whereType<String>()
                .firstOrNull;
            final gpu = parts
                .where((part) => part['role'] == 'gpu')
                .map((part) => part['name']?.toString())
                .whereType<String>()
                .firstOrNull;
            final total =
                (option['estimated_total'] as num?)?.round() ??
                parts.fold<int>(
                  0,
                  (sum, part) =>
                      sum + ((part['reference_price'] as num?)?.round() ?? 0),
                );
            return (
              title: option['title']?.toString() ?? '$badge方案',
              badge: badge,
              detail: [cpu, gpu].whereType<String>().join(' + '),
              price: '¥ ${_formatPrice(total)}',
              raw: option,
            );
          }).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UzPageHeader(title: '选择配置方案', centerTitle: false),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '可选方案',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '配置方向：均衡性价比',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ...visibleOptions.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => Navigator.of(
                      context,
                    ).push(uzRoute(BuildResultDemoScreen(option: option.raw))),
                    borderRadius: BorderRadius.circular(22),
                    child: UzSoftCard(
                      padding: const EdgeInsets.fromLTRB(24, 25, 24, 24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          option.title,
                                          style: const TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          height: 22,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: option.badge == '全新'
                                                ? const Color(0xFF4A6EAD)
                                                : option.badge == '混合'
                                                ? const Color(0xFFC27045)
                                                : const Color(0xFF469071),
                                            borderRadius: BorderRadius.circular(
                                              11,
                                            ),
                                          ),
                                          child: Text(
                                            option.badge,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 13),
                                    Text(
                                      option.detail,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                          const Divider(height: 44),
                          Row(
                            children: [
                              const Text(
                                '参考总价',
                                style: TextStyle(
                                  color: AppTheme.secondary,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                option.price,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPrice(int value) {
    final digits = value.toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
}

class ConfigReviewScreen extends StatefulWidget {
  const ConfigReviewScreen({super.key});

  @override
  State<ConfigReviewScreen> createState() => _ConfigReviewScreenState();
}

class _ConfigReviewScreenState extends State<ConfigReviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left_rounded, size: 38),
              ),
              const SizedBox(height: 24),
              const Text(
                '配置排雷',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '商家配置先别急着买，帮你看懂型号、价格和搭配风险',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),
              const _ReviewSectionNumber('01'),
              const SizedBox(height: 24),
              const Text(
                '上传配置单',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                '支持截图、照片和聊天记录',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '配置截图  ·  报价单照片  ·  聊天记录',
                style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 226,
                child: UzPrimaryButton(title: '选择图片', onPressed: _pickImage),
              ),
              const SizedBox(height: 28),
              const Divider(color: Color(0xFFE8E8E8)),
              const SizedBox(height: 28),
              const _ReviewSectionNumber('02'),
              const SizedBox(height: 24),
              const Text(
                '填写配置',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const Text(
                '逐项选择配件型号，并填写商家报价',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              const _ReviewRow(
                icon: Icons.memory_rounded,
                title: 'CPU / 主板',
                value: '选择型号',
              ),
              const _ReviewRow(
                icon: Icons.desktop_windows_outlined,
                title: '显卡 / 内存',
                value: '选择型号',
              ),
              const _ReviewRow(
                icon: Icons.bolt_rounded,
                title: '电源 / 商家总价',
                value: '填写价格',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 226,
                child: UzPrimaryButton(
                  title: '填写配置',
                  outlined: true,
                  onPressed: () => Navigator.of(
                    context,
                  ).push(uzRoute(const ConfigReviewManualScreen())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    Uint8List? bytes;
    var contentType = 'image/jpeg';
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (image == null) return;
      bytes = await image.readAsBytes();
      final name = image.name.toLowerCase();
      if (name.endsWith('.png')) contentType = 'image/png';
      if (name.endsWith('.webp')) contentType = 'image/webp';
    } catch (_) {
      // Restricted devices and widget tests can still exercise the flow.
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      uzRoute(
        ConfigReviewLoadingScreen(
          imageBytes: bytes,
          imageContentType: contentType,
        ),
      ),
    );
  }
}

class _ReviewSectionNumber extends StatelessWidget {
  const _ReviewSectionNumber(this.number);
  final String number;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$number  /',
      style: const TextStyle(
        color: Color(0xFFCCCCCC),
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF999999)),
        ],
      ),
    );
  }
}

class ConfigReviewManualScreen extends StatefulWidget {
  const ConfigReviewManualScreen({super.key});

  @override
  State<ConfigReviewManualScreen> createState() =>
      _ConfigReviewManualScreenState();
}

class _ConfigReviewManualScreenState extends State<ConfigReviewManualScreen> {
  static const fields = <({String title, IconData icon, List<String> models})>[
    (
      title: 'CPU',
      icon: Icons.memory_rounded,
      models: ['i9-14900KS', 'i9-14900KF', 'i7-14700KF', 'R7 9800X3D'],
    ),
    (
      title: '主板',
      icon: Icons.dashboard_outlined,
      models: ['华硕 ROG Z790-A', '微星 B760M 迫击炮', '华硕 PRIME B650M-K'],
    ),
    (
      title: '显卡',
      icon: Icons.desktop_windows_outlined,
      models: ['RTX 5070', 'RTX 4070', 'RX 9070 GRE'],
    ),
    (
      title: '内存',
      icon: Icons.memory_outlined,
      models: ['DDR5 32GB 6000 C30', 'DDR5 16GB 6000 C30'],
    ),
    (
      title: '硬盘',
      icon: Icons.storage_rounded,
      models: ['梵想 S790E 1TB', '西数 SN850X 1TB', '三星 990 PRO 2TB'],
    ),
    (
      title: '电源',
      icon: Icons.bolt_rounded,
      models: ['安耐美 GN650 V3 650W', '振华 LEADEX 750W', '海韵 FOCUS 850W'],
    ),
  ];

  final selectedModels = List<String>.filled(fields.length, '');
  late final List<TextEditingController> priceControllers;

  int get completedCount => List.generate(fields.length, (index) => index)
      .where(
        (index) =>
            selectedModels[index].isNotEmpty &&
            (int.tryParse(priceControllers[index].text) ?? 0) > 0,
      )
      .length;

  int get totalPrice => priceControllers.fold(
    0,
    (sum, controller) => sum + (int.tryParse(controller.text) ?? 0),
  );

  @override
  void initState() {
    super.initState();
    priceControllers = List.generate(
      fields.length,
      (_) => TextEditingController()..addListener(_refresh),
    );
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in priceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ReviewCenteredHeader(title: '填写配置'),
                  const SizedBox(height: 32),
                  const Text(
                    '填写配置',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '选择配件型号，再填写商家给出的单项价格',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ...List.generate(
                    fields.length,
                    (index) => _ConfigReviewInputRow(
                      field: fields[index],
                      model: selectedModels[index],
                      priceController: priceControllers[index],
                      onSelectModel: () => _showModelPicker(index),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '至少完成 2 项配件的型号与价格，即可开始排雷',
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xF2F7F7F7),
                  border: Border(top: BorderSide(color: Color(0xFFE8E8E8))),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(28, 15, 28, 10),
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '已填写 $completedCount 项',
                            style: const TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalPrice > 0 ? '¥$totalPrice' : '等待填写',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Opacity(
                        opacity: completedCount >= 2 ? 1 : 0.28,
                        child: SizedBox(
                          width: 176,
                          height: 54,
                          child: FilledButton(
                            onPressed: completedCount >= 2
                                ? () => Navigator.of(context).push(
                                    uzRoute(
                                      ConfigReviewLoadingScreen(
                                        sourceText: _sourceText(),
                                      ),
                                    ),
                                  )
                                : null,
                            style: FilledButton.styleFrom(
                              disabledBackgroundColor: Colors.black,
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '开始排雷',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
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

  Future<void> _showModelPicker(int index) async {
    final field = fields[index];
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择${field.title}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: Color(0xFF777777)),
                    SizedBox(width: 10),
                    Text('搜索型号', style: TextStyle(color: Color(0xFF999999))),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  itemCount: field.models.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, modelIndex) {
                    final model = field.models[modelIndex];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        model,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('推荐型号 · 主流装机平台'),
                      trailing: Icon(
                        selectedModels[index] == model
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                      ),
                      onTap: () => Navigator.pop(context, model),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() => selectedModels[index] = selected);
    }
  }

  String _sourceText() {
    final lines = <String>[];
    for (var index = 0; index < fields.length; index++) {
      final model = selectedModels[index];
      final price = int.tryParse(priceControllers[index].text);
      if (model.isNotEmpty) {
        lines.add(
          '${fields[index].title}：$model${price == null ? '' : '，¥$price'}',
        );
      }
    }
    lines.add('商家总价：¥$totalPrice');
    return lines.join('\n');
  }
}

class _ConfigReviewInputRow extends StatelessWidget {
  const _ConfigReviewInputRow({
    required this.field,
    required this.model,
    required this.priceController,
    required this.onSelectModel,
  });

  final ({String title, IconData icon, List<String> models}) field;
  final String model;
  final TextEditingController priceController;
  final VoidCallback onSelectModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 28, child: Icon(field.icon, size: 19)),
              const SizedBox(width: 12),
              Text(
                field.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSelectModel,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            model.isEmpty ? '选择型号' : model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: model.isEmpty
                                  ? const Color(0xFFAAAAAA)
                                  : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF999999),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 112,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Text(
                      '¥',
                      style: TextStyle(
                        color: Color(0xFF777777),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: '价格',
                          hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCenteredHeader extends StatelessWidget {
  const _ReviewCenteredHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_left_rounded, size: 32),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 32, height: 32, child: trailing),
        ],
      ),
    );
  }
}

class ConfigReviewLoadingScreen extends StatefulWidget {
  const ConfigReviewLoadingScreen({
    super.key,
    this.sourceText =
        'CPU：i9-14900KS，¥3999\n主板：华硕 ROG Z790-A，¥2599\n显卡：RTX 5070，¥4099\n电源：650W 金牌，¥399\n商家总价：¥11800',
    this.imageBytes,
    this.imageContentType = 'image/jpeg',
  });

  final String sourceText;
  final Uint8List? imageBytes;
  final String imageContentType;

  @override
  State<ConfigReviewLoadingScreen> createState() =>
      _ConfigReviewLoadingScreenState();
}

class _ConfigReviewLoadingScreenState extends State<ConfigReviewLoadingScreen> {
  Timer? progressTimer;
  double progress = 0.18;
  final api = UzBoxApi();

  @override
  void initState() {
    super.initState();
    progressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || progress >= 0.82) return;
      setState(() => progress = math.min(0.82, progress + 0.009));
    });
    unawaited(_analyze());
  }

  Future<void> _analyze() async {
    Map<String, dynamic>? result;
    final request =
        (widget.imageBytes == null
                ? api.reviewText(widget.sourceText)
                : api.reviewImage(
                    widget.imageBytes!,
                    contentType: widget.imageContentType,
                  ))
            .then((value) {
              result = value;
            })
            .catchError((Object _) {});
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      Future.any([request, Future.delayed(const Duration(milliseconds: 6200))]),
    ]);
    if (!mounted) return;
    setState(() => progress = 1);
    await Navigator.of(
      context,
    ).pushReplacement(uzRoute(ConfigReviewResultScreen(result: result)));
  }

  @override
  void dispose() {
    progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondComplete = progress > 0.36;
    final thirdActive = progress > 0.58;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ReviewCenteredHeader(title: '配置排雷'),
              const SizedBox(height: 32),
              const Text(
                '正在检查这套配置',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '通常需要 10–20 秒，请稍等一下',
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  SizedBox(
                    width: 126,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${(progress * 100).round()}',
                                style: const TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(
                                text: '  / 100',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '正在核对型号与价格',
                          style: TextStyle(
                            color: Color(0xFF777777),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0.2126,
                        0.7152,
                        0.0722,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: Image.asset(
                        'assets/images/home_hero_config_review_board.png',
                        height: 260,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '检查进度',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              const _ReviewProgressRow(
                number: '01',
                title: '读取配件型号',
                status: _ReviewProgressStatus.completed,
              ),
              _ReviewProgressRow(
                number: '02',
                title: '检查兼容性',
                status: secondComplete
                    ? _ReviewProgressStatus.completed
                    : _ReviewProgressStatus.waiting,
              ),
              _ReviewProgressRow(
                number: '03',
                title: '分析性能与预算',
                status: thirdActive
                    ? _ReviewProgressStatus.active
                    : _ReviewProgressStatus.waiting,
              ),
              const _ReviewProgressRow(
                number: '04',
                title: '整理购买建议',
                status: _ReviewProgressStatus.waiting,
                showDivider: false,
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  '分析期间可以保持当前页面',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ReviewProgressStatus { completed, active, waiting }

class _ReviewProgressRow extends StatelessWidget {
  const _ReviewProgressRow({
    required this.number,
    required this.title,
    required this.status,
    this.showDivider = true,
  });
  final String number;
  final String title;
  final _ReviewProgressStatus status;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final statusTitle = switch (status) {
      _ReviewProgressStatus.completed => '已完成',
      _ReviewProgressStatus.active => '进行中',
      _ReviewProgressStatus.waiting => '等待中',
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '$number   /',
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 27,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (status == _ReviewProgressStatus.completed)
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                )
              else if (status == _ReviewProgressStatus.active)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              else
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFCCCCCC),
                      width: 2,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                statusTitle,
                style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConfigReviewResultScreen extends StatelessWidget {
  const ConfigReviewResultScreen({super.key, this.result});

  final Map<String, dynamic>? result;

  @override
  Widget build(BuildContext context) {
    final findings = (result?['findings'] as List? ?? const <Object>[])
        .whereType<Map<String, dynamic>>()
        .where((finding) => finding['level'] != 'pass')
        .toList();
    final riskLevel = result?['risk_level']?.toString();
    final conclusion = switch (riskLevel) {
      'pass' => '可以放心购买',
      'error' => '不建议购买',
      _ => '建议修改后再买',
    };
    final summary =
        result?['summary']?.toString() ?? '这套配置存在电源余量和价格偏高问题，建议确认修改后再下单。';
    final visibleFindings = result == null
        ? const [
            {
              'title': '电源余量偏紧',
              'detail': '已识别配件估算功耗较高，当前电源余量偏紧，建议更换 750W 金牌电源。',
            },
            {'title': '商家报价偏高', 'detail': '商家报价已经高出同档配置的正常装机服务溢价，建议重新确认报价。'},
          ]
        : findings;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ReviewCenteredHeader(
                    title: '排雷报告',
                    trailing: Icon(Icons.ios_share_rounded, size: 20),
                  ),
                  const SizedBox(height: 34),
                  const Text(
                    '综合结论',
                    style: TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    conclusion,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ReviewMetrics(
                    riskCount: visibleFindings.length,
                    sellerPrice: (result?['seller_price'] as num?)?.round(),
                    referenceTotal: (result?['reference_total'] as num?)
                        ?.round(),
                  ),
                  const SizedBox(height: 42),
                  Text(
                    '先处理这 ${visibleFindings.length} 个问题',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    visibleFindings.length,
                    (index) => _ReviewFinding(
                      index: index + 1,
                      title:
                          visibleFindings[index]['title']?.toString() ?? '配置提醒',
                      detail:
                          visibleFindings[index]['detail']?.toString() ?? '',
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    children: [
                      _ReviewCheckCircle(),
                      SizedBox(width: 14),
                      Text(
                        '已完成兼容性、搭配与价格检查',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xF2F7F7F7),
                  border: Border(top: BorderSide(color: Color(0xFFE8E8E8))),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(24, 15, 24, 10),
                  child: Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '已为你整理好回复话术',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 11,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${visibleFindings.length} 个修改建议',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 174,
                        height: 54,
                        child: FilledButton(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已复制给商家的回复')),
                              ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '复制给商家',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 14),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
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
}

class _ReviewMetrics extends StatelessWidget {
  const _ReviewMetrics({
    required this.riskCount,
    this.sellerPrice,
    this.referenceTotal,
  });

  final int riskCount;
  final int? sellerPrice;
  final int? referenceTotal;

  @override
  Widget build(BuildContext context) {
    final difference = sellerPrice != null && referenceTotal != null
        ? sellerPrice! - referenceTotal!
        : null;
    return Row(
      children: [
        const Expanded(
          child: _ReviewMetric(title: '兼容性', value: '通过'),
        ),
        const SizedBox(height: 42, child: VerticalDivider()),
        Expanded(
          child: _ReviewMetric(
            title: '预算',
            value: difference == null
                ? '等待核对'
                : difference > 0
                ? '偏高 ¥$difference'
                : '合理',
          ),
        ),
        const SizedBox(height: 42, child: VerticalDivider()),
        Expanded(
          child: _ReviewMetric(title: '风险项', value: '$riskCount 个'),
        ),
      ],
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ReviewCheckCircle extends StatelessWidget {
  const _ReviewCheckCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
    );
  }
}

class _ReviewFinding extends StatelessWidget {
  const _ReviewFinding({
    required this.index,
    required this.title,
    required this.detail,
  });
  final int index;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '${index.toString().padLeft(2, '0')}   /',
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
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

class UpgradePlanScreen extends StatefulWidget {
  const UpgradePlanScreen({super.key});

  @override
  State<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends State<UpgradePlanScreen> {
  final api = UzBoxApi();
  static const parts = ['CPU', '显卡', '主板', '电源', '内存', '硬盘'];
  static const games = [
    '无畏契约',
    'CS2',
    'PUBG',
    '三角洲行动',
    '云顶之弈',
    '英雄联盟',
    '使命召唤',
    '赛博朋克2077',
    '荒野大镖客2',
    'GTA5',
    '黑神话悟空',
    '地平线6',
    '艾尔登法环',
    '城市天际线',
    '我的世界',
  ];
  int step = 0;
  int goal = 1;
  double budget = 3000;
  String resolution = '2K';
  int? frameTarget;
  final selectedGames = <String>{};
  Map<String, dynamic>? upgradeResult;
  bool isGenerating = false;

  static const gameIds = {
    '无畏契约': 'valorant',
    'CS2': 'cs2',
    'PUBG': 'pubg',
    '三角洲行动': 'delta-force',
    '云顶之弈': 'teamfight-tactics',
    '英雄联盟': 'league-of-legends',
    '使命召唤': 'call-of-duty-warzone',
    '赛博朋克2077': 'cyberpunk-2077',
    '荒野大镖客2': 'red-dead-redemption-2',
    'GTA5': 'gta-v',
    '黑神话悟空': 'black-myth-wukong',
    '地平线6': 'forza-horizon-6',
    '艾尔登法环': 'elden-ring',
    '城市天际线': 'cities-skylines',
    '我的世界': 'minecraft-java-edition',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFA),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 116),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UzPageHeader(
                    title: '升级建议',
                    trailing: Text(
                      '${step + 1} / 3',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 31),
                  if (step == 0) ..._computerStep(),
                  if (step == 1) ..._goalStep(),
                  if (step == 2) ..._resultStep(),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                child: step == 2
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => step = 1),
                            child: const Text(
                              '重新调整条件',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          UzPrimaryButton(
                            title: '保存升级方案',
                            height: 56,
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('升级方案已保存')),
                                ),
                          ),
                        ],
                      )
                    : UzPrimaryButton(
                        title: step == 0
                            ? '下一步'
                            : isGenerating
                            ? '正在生成…'
                            : '生成升级方案',
                        height: 58,
                        onPressed: isGenerating
                            ? null
                            : () {
                                if (step < 2) {
                                  if (step == 1 &&
                                      goal == 1 &&
                                      selectedGames.isEmpty) {
                                    showDialog<void>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('请选择一个游戏'),
                                        content: const Text(
                                          '至少选择一个优先参考的游戏后，才能生成游戏性能升级方案。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('知道了'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  if (step == 1) {
                                    unawaited(_generateUpgrade());
                                  } else {
                                    setState(() => step += 1);
                                  }
                                }
                              },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _computerStep() => [
    const Text(
      '告诉我，\n你现在用的电脑。',
      style: TextStyle(
        fontSize: 38,
        height: 1.28,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
      ),
    ),
    const SizedBox(height: 17),
    const Text(
      '先填你知道的配置，不清楚的项目可以选“不知道”',
      style: TextStyle(color: Color(0xFF888888), fontSize: 14),
    ),
    const SizedBox(height: 31),
    const Text(
      '核心配置',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 5),
    const Text(
      '用于判断性能短板与兼容性',
      style: TextStyle(color: Color(0xFF999999), fontSize: 13),
    ),
    const SizedBox(height: 16),
    ...List.generate(
      parts.length,
      (index) => _UpgradePartRow(index: index, title: parts[index]),
    ),
  ];

  List<Widget> _goalStep() => [
    const Text(
      '你想先解决哪种问题？',
      maxLines: 1,
      style: TextStyle(
        fontSize: 35,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      '只显示与你目标有关的选项',
      style: TextStyle(color: Color(0xFF888888), fontSize: 14),
    ),
    const SizedBox(height: 28),
    Row(
      children: [
        _UpgradeGoalCard(
          icon: Icons.verified_user_outlined,
          title: '帮我找短板',
          subtitle: '不知道该先换什么',
          selected: goal == 0,
          onTap: () => setState(() => goal = 0),
        ),
        const SizedBox(width: 12),
        _UpgradeGoalCard(
          icon: Icons.sports_esports_outlined,
          title: '游戏性能',
          subtitle: '提升帧率与画质',
          selected: goal == 1,
          onTap: () => setState(() => goal = 1),
        ),
      ],
    ),
    const SizedBox(height: 36),
    Text(
      goal == 1 ? '游戏性能目标' : '升级条件',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
    ),
    const SizedBox(height: 24),
    const Text(
      '预算上限',
      style: TextStyle(color: AppTheme.secondary, fontSize: 13),
    ),
    const SizedBox(height: 12),
    Center(
      child: Text(
        '¥${budget.round()}',
        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
      ),
    ),
    Slider(
      min: 500,
      max: 12000,
      divisions: 23,
      value: budget,
      activeColor: Colors.black,
      onChanged: (value) => setState(() => budget = value),
    ),
    const Row(
      children: [
        Text('¥500', style: TextStyle(fontSize: 11)),
        Spacer(),
        Text('¥12000', style: TextStyle(fontSize: 11)),
      ],
    ),
    if (goal == 1) ...[
      const SizedBox(height: 26),
      const Text(
        '优先参考的游戏（可多选）',
        style: TextStyle(color: AppTheme.secondary, fontSize: 13),
      ),
      const SizedBox(height: 14),
      InkWell(
        onTap: _showUpgradeGamePicker,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 82,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: selectedGames.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 26),
                    SizedBox(height: 6),
                    Text('添加游戏', style: TextStyle(fontSize: 11)),
                  ],
                )
              : Row(
                  children: selectedGames
                      .take(3)
                      .map(
                        (game) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                game,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ),
      const SizedBox(height: 28),
      const Text(
        '性能目标',
        style: TextStyle(color: AppTheme.secondary, fontSize: 13),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(
                () => resolution = resolution == '2K' ? '1080P' : '2K',
              ),
              child: _UpgradeTarget(value: resolution, title: '分辨率'),
            ),
          ),
          const SizedBox(height: 70, child: VerticalDivider()),
          Expanded(
            child: InkWell(
              onTap: selectedGames.isEmpty
                  ? null
                  : () => setState(
                      () => frameTarget = frameTarget == null ? 144 : null,
                    ),
              child: _UpgradeTarget(
                value: frameTarget == null ? '—' : '$frameTarget',
                title: frameTarget == null ? '选择游戏后计算' : '参考上限 $frameTarget 帧',
              ),
            ),
          ),
        ],
      ),
    ],
  ];

  Future<void> _showUpgradeGamePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: StatefulBuilder(
          builder: (context, sheetSetState) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择常玩的游戏',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  '可以多选，推荐结果会优先参考这些游戏。',
                  style: TextStyle(color: AppTheme.secondary, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: games.map((game) {
                      final selected = selectedGames.contains(game);
                      return ListTile(
                        title: Text(game),
                        trailing: Icon(
                          selected ? Icons.check_rounded : Icons.add_rounded,
                        ),
                        onTap: () => sheetSetState(() {
                          selected
                              ? selectedGames.remove(game)
                              : selectedGames.add(game);
                        }),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _generateUpgrade() async {
    setState(() => isGenerating = true);
    Map<String, dynamic>? result;
    try {
      result = await api.upgradePlan(
        budget: budget.round(),
        current: const {
          'cpu': 'i5-14600k',
          'gpu': 'rtx-4070',
          'motherboard': 'gigabyte-b760m-elite-g5',
          'psu': 'psu-corsair-rm750e',
        },
        need: goal == 1 ? '提升游戏帧率与画质' : '均衡提升',
        games: selectedGames
            .map((game) => gameIds[game])
            .whereType<String>()
            .toList(),
        resolution: resolution == '2K' ? '2k' : '1080p',
        targetFps: frameTarget ?? 144,
      );
    } catch (_) {
      // Preserve the calibrated local recommendation when offline.
    }
    if (!mounted) return;
    setState(() {
      upgradeResult = result;
      isGenerating = false;
      step = 2;
    });
  }

  List<Widget> _resultStep() {
    final steps = (upgradeResult?['steps'] as List? ?? const <Object>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    final gameResults =
        (upgradeResult?['game_results'] as List? ?? const <Object>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    final total =
        (upgradeResult?['total_estimated_price'] as num?)?.round() ??
        budget.round();
    final summary =
        upgradeResult?['summary']?.toString() ?? '先更换对帧率影响最大的配件，再补齐电源与内存。';
    return [
      const Text(
        '这台电脑，\n按这个顺序升级。',
        style: TextStyle(
          fontSize: 38,
          height: 1.25,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        summary,
        style: const TextStyle(color: AppTheme.secondary, fontSize: 14),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '预估可达成目标',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '先升级显卡',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '目标：2K · 144 帧',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            Text(
              '¥$total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      const Text(
        '升级顺序',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      if (steps.isEmpty) ...const [
        _UpgradeResultRow('01', '显卡', 'GeForce RTX 5070 · ¥4,099'),
        _UpgradeResultRow('02', '电源', '750W 金牌 · ¥469'),
        _UpgradeResultRow('03', '内存', 'DDR5 32GB · ¥529'),
      ] else
        ...List.generate(
          steps.length,
          (index) => _UpgradeResultRow(
            '${index + 1}'.padLeft(2, '0'),
            _upgradeRoleTitle(steps[index]['role']?.toString() ?? ''),
            '${steps[index]['to_name'] ?? ''} · ¥${steps[index]['estimated_price'] ?? 0}',
          ),
        ),
      const SizedBox(height: 28),
      const Text(
        '预估游戏表现',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      if (gameResults.isEmpty) ...const [
        _UpgradeResultRow('✓', '瓦罗兰特', '386 → 474 帧（目标 144）'),
        _UpgradeResultRow('✓', 'CS2', '168 → 227 帧（目标 144）'),
        _UpgradeResultRow('—', 'PUBG', '86 → 112 帧（目标 144）'),
      ] else
        ...gameResults.map(
          (game) => _UpgradeResultRow(
            game['met'] == true ? '✓' : '—',
            game['game']?.toString() ?? '',
            '${game['before_fps'] ?? 0} → ${game['after_fps'] ?? 0} 帧（目标 ${game['target_fps'] ?? 0}）',
          ),
        ),
      const SizedBox(height: 26),
      const Text(
        '说明',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      const Text(
        '· 先更换对帧率影响最大的显卡，再补齐电源与内存。\n'
        '· 实际表现会受游戏版本、驱动、散热和后台程序影响。',
        style: TextStyle(color: AppTheme.secondary, fontSize: 13, height: 1.7),
      ),
    ];
  }

  static String _upgradeRoleTitle(String role) => switch (role) {
    'cpu' => 'CPU',
    'gpu' => '显卡',
    'motherboard' => '主板',
    'ram' => '内存',
    'psu' => '电源',
    _ => role,
  };
}

class _UpgradeTarget extends StatelessWidget {
  const _UpgradeTarget({required this.value, required this.title});
  final String value;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
          ],
        ),
      ),
      const Icon(Icons.chevron_right_rounded, size: 20),
    ],
  );
}

class _UpgradeGoalCard extends StatelessWidget {
  const _UpgradeGoalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: selected ? null : Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.black),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected ? Colors.white60 : AppTheme.secondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpgradeResultRow extends StatelessWidget {
  const _UpgradeResultRow(this.number, this.title, this.detail);
  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              number,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }
}

class _UpgradePartRow extends StatelessWidget {
  const _UpgradePartRow({required this.index, required this.title});
  final int index;
  final String title;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Container(
        height: 66,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFD8D8D8))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  '不知道',
                  style: TextStyle(color: Color(0xFF999999), fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_rounded, size: 24),
          ],
        ),
      ),
    );
  }
}

class GamePerformanceScreen extends StatefulWidget {
  const GamePerformanceScreen({super.key});

  @override
  State<GamePerformanceScreen> createState() => _GamePerformanceScreenState();
}

class _GamePerformanceScreenState extends State<GamePerformanceScreen> {
  final api = UzBoxApi();
  final selected = <int>{};
  String cpu = '';
  String gpu = '';
  bool isSubmitting = false;

  static const cpuOptions = [
    'i9-14900KS',
    'i9-14900KF',
    'i7-14700KF',
    'i5-14600KF',
    'R7 9800X3D',
  ];
  static const gpuOptions = [
    'Intel Arc B580 12GB',
    'RTX 5070',
    'RTX 4070',
    'RX 9070 GRE',
  ];
  static const cpuIds = {
    'i9-14900KS': 'i9-14900ks',
    'i9-14900KF': 'i9-14900kf',
    'i7-14700KF': 'i7-14700kf',
    'i5-14600KF': 'i5-14600kf',
    'R7 9800X3D': 'r7-9800x3d',
  };
  static const gpuIds = {
    'Intel Arc B580 12GB': 'arc-b580-12gb',
    'RTX 5070': 'rtx-5070',
    'RTX 4070': 'rtx-4070',
    'RX 9070 GRE': 'rx-9070-gre',
  };
  static const gameIds = {
    '瓦罗兰特': 'valorant',
    'CS2': 'cs2',
    'PUBG': 'pubg',
    '三角洲行动': 'delta-force',
    '云顶之弈': 'teamfight-tactics',
    'LOL': 'league-of-legends',
    'COD': 'call-of-duty-warzone',
    '赛博朋克 2077': 'cyberpunk-2077',
    '荒野大镖客 2': 'red-dead-redemption-2',
    'GTA5': 'gta-v',
    '黑神话悟空': 'black-myth-wukong',
  };

  static const games = <({String title, String asset})>[
    (title: '瓦罗兰特', asset: 'assets/images/game_valorant.png'),
    (title: 'CS2', asset: 'assets/images/game_cs2.png'),
    (title: 'PUBG', asset: 'assets/images/game_pubg.png'),
    (title: '三角洲行动', asset: 'assets/images/game_delta_force.png'),
    (title: '云顶之弈', asset: 'assets/images/game_tft.png'),
    (title: 'LOL', asset: 'assets/images/game_lol.png'),
    (title: 'COD', asset: 'assets/images/game_cod.png'),
    (title: '赛博朋克 2077', asset: 'assets/images/game_cyberpunk.png'),
    (title: '荒野大镖客 2', asset: 'assets/images/game_rdr2.png'),
    (title: 'GTA5', asset: 'assets/images/game_gta5.png'),
    (title: '黑神话悟空', asset: 'assets/images/game_wukong.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const UzPageHeader(title: '游戏性能测试'),
                  const SizedBox(height: 19),
                  Row(
                    children: [
                      const Text(
                        '测试配置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '仅需 CPU 和显卡',
                        style: TextStyle(
                          color: AppTheme.secondary.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  UzSoftCard(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HardwarePick(
                            icon: Icons.memory_rounded,
                            title: 'CPU',
                            value: cpu.isEmpty ? '未选择' : cpu,
                            onTap: () => _showHardwarePicker(
                              'CPU',
                              cpuOptions,
                              (value) => setState(() => cpu = value),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 44,
                          child: VerticalDivider(color: AppTheme.border),
                        ),
                        Expanded(
                          child: _HardwarePick(
                            icon: Icons.desktop_windows_outlined,
                            title: '显卡',
                            value: gpu.isEmpty ? '未选择' : gpu,
                            onTap: () => _showHardwarePicker(
                              '显卡',
                              gpuOptions,
                              (value) => setState(() => gpu = value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 31),
                  Row(
                    children: [
                      const Text(
                        '选择游戏',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '已选择 ${selected.length} 款',
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 18),
                      TextButton(
                        onPressed: () => setState(() {
                          if (selected.length == games.length) {
                            selected.clear();
                          } else {
                            selected.addAll(
                              List.generate(games.length, (index) => index),
                            );
                          }
                        }),
                        child: const Text(
                          '全选',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  UzSoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: List.generate(games.length, (index) {
                        final game = games[index];
                        return InkWell(
                          onTap: () => setState(() {
                            selected.contains(index)
                                ? selected.remove(index)
                                : selected.add(index);
                          }),
                          child: SizedBox(
                            height: 74,
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    game.asset,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Container(
                                    height: 74,
                                    alignment: Alignment.centerLeft,
                                    decoration: index == games.length - 1
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
                                        Text(
                                          game.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: selected.contains(index)
                                                ? Colors.black
                                                : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: selected.contains(index)
                                                  ? Colors.black
                                                  : AppTheme.border,
                                              width: 2,
                                            ),
                                          ),
                                          child: selected.contains(index)
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 15,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 14),
                                      ],
                                    ),
                                  ),
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
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: UzPrimaryButton(
                  title: isSubmitting ? '正在计算…' : '查看预计帧率',
                  backgroundColor: AppTheme.primary,
                  onPressed: isSubmitting ? null : _openResults,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openResults() async {
    final chosenCpu = cpu.isEmpty ? 'i9-14900KS' : cpu;
    final chosenGpu = gpu.isEmpty ? 'Intel Arc B580 12GB' : gpu;
    final chosenIndexes = selected.isEmpty ? {0, 1, 2} : selected;
    final chosenGames = chosenIndexes.map((index) => games[index]).toList();
    setState(() => isSubmitting = true);
    Map<String, int> fps = const {};
    int? timeSpyScore;
    try {
      final response = await api.estimatePerformance(
        cpuId: cpuIds[chosenCpu] ?? 'i9-14900ks',
        gpuId: gpuIds[chosenGpu] ?? 'arc-b580-12gb',
        resolution: '2k',
        gameIds: chosenGames
            .map((game) => gameIds[game.title])
            .whereType<String>()
            .toList(),
      );
      timeSpyScore = (response['gpu_time_spy_score'] as num?)?.round();
      fps = {
        for (final result
            in (response['game_results'] as List? ?? const <Object>[])
                .whereType<Map<String, dynamic>>())
          if (result['game'] != null && result['average_fps'] is num)
            result['game'].toString(): (result['average_fps'] as num).round(),
      };
    } catch (_) {
      // Keep the calibrated local values available when the API is offline.
    }
    if (!mounted) return;
    setState(() => isSubmitting = false);
    await Navigator.of(context).push(
      uzRoute(
        PerformanceResultScreen(
          games: chosenGames,
          cpu: chosenCpu,
          gpu: chosenGpu,
          timeSpyScore: timeSpyScore,
          fpsByGameId: fps,
        ),
      ),
    );
  }

  Future<void> _showHardwarePicker(
    String title,
    List<String> options,
    ValueChanged<String> onSelected,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 18, 12),
              child: Row(
                children: [
                  Text(
                    '选择$title',
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
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PerformanceResultScreen extends StatefulWidget {
  const PerformanceResultScreen({
    super.key,
    required this.games,
    this.cpu = 'i9-14900KS',
    this.gpu = 'Intel Arc B580 12GB',
    this.timeSpyScore,
    this.fpsByGameId = const {},
  });

  final List<({String title, String asset})> games;
  final String cpu;
  final String gpu;
  final int? timeSpyScore;
  final Map<String, int> fpsByGameId;

  @override
  State<PerformanceResultScreen> createState() =>
      _PerformanceResultScreenState();
}

class _PerformanceResultScreenState extends State<PerformanceResultScreen> {
  int resolution = 1;

  @override
  Widget build(BuildContext context) {
    final timeSpyScore = widget.timeSpyScore ?? 14688;
    final formattedTimeSpy = timeSpyScore >= 1000
        ? '${timeSpyScore ~/ 1000},${(timeSpyScore % 1000).toString().padLeft(3, '0')}'
        : '$timeSpyScore';
    const fpsByResolution = [
      [534, 332, 236, 188, 264, 296],
      [474, 227, 184, 156, 228, 258],
      [342, 156, 98, 104, 160, 184],
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                children: [
                  const UzPageHeader(title: '性能结果'),
                  const SizedBox(height: 20),
                  UzSoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 172,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 11,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    10,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Time Spy 显卡分数',
                                        style: TextStyle(
                                          color: AppTheme.secondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        formattedTimeSpy,
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Text(
                                        '3DMark 图形性能基准',
                                        style: TextStyle(
                                          color: AppTheme.secondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F3F5),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Expanded(
                                              child: _PerformanceMetric(
                                                title: '性能级别',
                                                value: '高端级',
                                              ),
                                            ),
                                            VerticalDivider(),
                                            Expanded(
                                              child: _PerformanceMetric(
                                                title: '超越用户',
                                                value: '62%',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const VerticalDivider(indent: 12, endIndent: 12),
                              Expanded(
                                flex: 9,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: _PerformanceGauge(score: timeSpyScore),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: UzSegmentedControl(
                            options: const ['1080P', '2K', '4K'],
                            selected: resolution,
                            height: 44,
                            selectedColor: AppTheme.primary,
                            selectedForeground: Colors.white,
                            onSelected: (value) =>
                                setState(() => resolution = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  UzSoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: List.generate(widget.games.length, (index) {
                        final game = widget.games[index];
                        final gameId =
                            _GamePerformanceScreenState.gameIds[game.title];
                        final value = resolution == 1 && gameId != null
                            ? widget.fpsByGameId[gameId] ??
                                  fpsByResolution[resolution][index % 6]
                            : fpsByResolution[resolution][index % 6];
                        return Container(
                          constraints: const BoxConstraints(minHeight: 95.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: index == widget.games.length - 1
                              ? null
                              : const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: AppTheme.border),
                                  ),
                                ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  game.asset,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      game.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      '预计平均帧率',
                                      style: TextStyle(
                                        color: AppTheme.secondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$value',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'FPS',
                                style: TextStyle(
                                  color: AppTheme.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PerformanceHardwareSummary(cpu: widget.cpu, gpu: widget.gpu),
                  const SizedBox(height: 12),
                  const Text(
                    '预计结果基于各游戏已校准的高画质条件；超分与帧生成设置以对应测试样本为准。实际表现会受游戏版本、驱动、散热和后台程序影响。',
                    style: TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('修改测试内容'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceMetric extends StatelessWidget {
  const _PerformanceMetric({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        title,
        style: const TextStyle(color: AppTheme.secondary, fontSize: 9),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _PerformanceGauge extends StatelessWidget {
  const _PerformanceGauge({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _PerformanceGaugePainter(score),
    child: const SizedBox.expand(),
  );
}

class _PerformanceGaugePainter extends CustomPainter {
  const _PerformanceGaugePainter(this.score);

  final int score;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .46, size.height * .72);
    final radius = size.width * .45;
    final track = Paint()
      ..color = const Color(0xFFE1E6ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final progress = (score / 47539).clamp(0.0, 1.0);
    final active = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      track,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * progress,
      false,
      active,
    );
    final needle = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;
    final end =
        center +
        Offset(
          math.cos(math.pi + math.pi * progress) * radius * .85,
          math.sin(math.pi + math.pi * progress) * radius * .85,
        );
    canvas.drawLine(center, end, needle);
    canvas.drawCircle(center, 6, Paint()..color = Colors.black);
    final tp = TextPainter(
      text: const TextSpan(
        text: '47K',
        style: TextStyle(color: AppTheme.secondary, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final zero = TextPainter(
      text: const TextSpan(
        text: '0',
        style: TextStyle(color: AppTheme.secondary, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zero.paint(canvas, Offset(3, size.height * .80));
    tp.paint(canvas, Offset(size.width - tp.width - 3, size.height * .80));
  }

  @override
  bool shouldRepaint(covariant _PerformanceGaugePainter oldDelegate) =>
      oldDelegate.score != score;
}

class _PerformanceHardwareSummary extends StatelessWidget {
  const _PerformanceHardwareSummary({required this.cpu, required this.gpu});

  final String cpu;
  final String gpu;

  @override
  Widget build(BuildContext context) {
    return UzSoftCard(
      padding: EdgeInsets.all(13),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '测试配置',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PerformanceHardwareItem(
                  icon: Icons.memory_rounded,
                  title: 'CPU',
                  value: cpu,
                ),
              ),
              SizedBox(
                height: 34,
                child: VerticalDivider(color: AppTheme.border),
              ),
              Expanded(
                child: _PerformanceHardwareItem(
                  icon: Icons.desktop_windows_outlined,
                  title: '显卡',
                  value: gpu,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceHardwareItem extends StatelessWidget {
  const _PerformanceHardwareItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: AppTheme.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.secondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HardwarePick extends StatelessWidget {
  const _HardwarePick({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F6),
              borderRadius: BorderRadius.circular(13),
              boxShadow: AppTheme.cardShadow(opacity: 0.04),
            ),
            child: Icon(icon, size: 23),
          ),
          const SizedBox(width: 10),
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
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.secondary),
        ],
      ),
    );
  }
}

class StyleOverviewScreen extends StatefulWidget {
  const StyleOverviewScreen({
    super.key,
    this.title = '联立 VISION COMPACT',
    this.image = 'assets/images/style_vision_compact_black.webp',
    this.whiteImage = 'assets/images/style_vision_compact_white.webp',
    this.total = '6,520',
    this.whiteTotal = '6,580',
  });

  final String title;
  final String image;
  final String whiteImage;
  final String total;
  final String whiteTotal;

  @override
  State<StyleOverviewScreen> createState() => _StyleOverviewScreenState();
}

class _StyleOverviewScreenState extends State<StyleOverviewScreen> {
  int color = 0;
  final replacements = <String, String>{};

  String get displayedTotal {
    final source = color == 0 ? widget.total : widget.whiteTotal;
    final base = int.tryParse(source.replaceAll(',', '')) ?? 0;
    final discount = parts
        .where((part) => replacements.containsKey(part.title))
        .map(
          (part) =>
              int.tryParse(part.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .fold<int>(0, (sum, price) => sum + price * 3 ~/ 10);
    final value = (base - discount).clamp(0, base).toString();
    return value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  List<({IconData icon, String title, String detail, String price})>
  get parts => <({IconData icon, String title, String detail, String price})>[
    (
      icon: Icons.rectangle_outlined,
      title: '机箱',
      detail: widget.title,
      price: '¥679',
    ),
    (
      icon: Icons.water_drop_outlined,
      title: '一体式水冷',
      detail: '展域 SE360',
      price: '¥1,799',
    ),
    (
      icon: Icons.desktop_windows_outlined,
      title: '副屏',
      detail: '图灵智显 8.8 寸副屏',
      price: '¥340',
    ),
    (
      icon: Icons.toys_outlined,
      title: '风扇套装',
      detail: '联立四代风扇 8 把 + 无线发射器',
      price: '¥3,000',
    ),
    (
      icon: Icons.cable_rounded,
      title: '霓虹线',
      detail: '联立 4 代霓虹线',
      price: '¥700',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 116),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UzPageHeader(title: '方案介绍', centerTitle: false),
                  SizedBox(
                    height: 244,
                    width: double.infinity,
                    child: Transform.translate(
                      offset: const Offset(0, -9),
                      child: Transform.scale(
                        scale: 1.11,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Image.asset(
                            color == 0 ? widget.image : widget.whiteImage,
                            key: ValueKey(color),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Transform.translate(
                    offset: const Offset(0, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        _StyleColorPicker(
                          selected: color,
                          onSelected: (value) => setState(() => color = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    '方案配件',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...parts.map(
                    (part) => _StylePartRow(
                      part: part,
                      hasReplacement: replacements.containsKey(part.title),
                      onReplace: () => _showReplacement(part),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '外观配件费用',
                            style: TextStyle(
                              color: AppTheme.secondary,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '¥$displayedTotal',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 184,
                        height: 40,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(
                            context,
                          ).push(uzRoute(const AestheticBuildScreen())),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '按这个方案装机',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 14),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
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

  void _showReplacement(
    ({IconData icon, String title, String detail, String price}) part,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.62,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '选择平替',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              part.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '选择替代配件后，外观配件费用会同步更新。',
              style: TextStyle(color: AppTheme.secondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _ReplacementOption(
              title: part.detail,
              subtitle: '原方案配件',
              price: part.price,
              selected: !replacements.containsKey(part.title),
              onTap: () {
                setState(() => replacements.remove(part.title));
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _ReplacementOption(
              title: '${part.title}高性价比替代',
              subtitle: '保留同类外观与功能',
              price:
                  '¥${(int.tryParse(part.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 500) * 7 ~/ 10}',
              selected: replacements.containsKey(part.title),
              onTap: () {
                setState(() => replacements[part.title] = '平替');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplacementOption extends StatelessWidget {
  const _ReplacementOption({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF5F7F8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: selected ? Colors.white60 : AppTheme.secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleColorPicker extends StatelessWidget {
  const _StyleColorPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(2, (index) {
          final active = selected == index;
          return Material(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            elevation: active ? 2 : 0,
            shadowColor: Colors.black.withValues(alpha: 0.20),
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 57,
                height: 26,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == 0 ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                        border: index == 1
                            ? Border.all(color: Colors.black26, width: 0.8)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      index == 0 ? '黑色' : '白色',
                      style: TextStyle(
                        color: active ? AppTheme.primary : AppTheme.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StylePartRow extends StatelessWidget {
  const _StylePartRow({
    required this.part,
    required this.hasReplacement,
    required this.onReplace,
  });
  final ({IconData icon, String title, String detail, String price}) part;
  final bool hasReplacement;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 34, child: Icon(part.icon, size: 15)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  part.detail,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            part.price,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 54,
            height: 28,
            child: FilledButton(
              onPressed: onReplace,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                hasReplacement ? '已换' : '替换',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AestheticBuildScreen extends StatefulWidget {
  const AestheticBuildScreen({super.key});

  @override
  State<AestheticBuildScreen> createState() => _AestheticBuildScreenState();
}

class _AestheticBuildScreenState extends State<AestheticBuildScreen> {
  int step = 0;
  double budget = 8000;

  @override
  Widget build(BuildContext context) {
    const titles = ['预算和用途', '常玩游戏', '体验目标', '预算预估'];
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
              child: Column(
                children: [
                  const UzPageHeader(title: '按风格装机'),
                  const SizedBox(height: 14),
                  _StepHeader(step: step, titles: titles),
                  const SizedBox(height: 20),
                  UzSoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titles[step],
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step == 0
                              ? '外观方案费用已单独计算，AI 会按性能预算选择其他核心配件。'
                              : '继续补充需求，生成与这个外观方案匹配的整机配置。',
                          style: const TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (step == 0) ...[
                          Row(
                            children: [
                              const Text(
                                '性能预算',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const Spacer(),
                              Text(
                                '¥ ${budget.round()}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: 4000,
                            max: 30000,
                            value: budget,
                            onChanged: (value) =>
                                setState(() => budget = value),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '外观配件费用（另计）',
                            style: TextStyle(color: AppTheme.secondary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '¥6,520',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ] else
                          const Text(
                            '已按当前方案选择推荐项，可继续下一步。',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: UzBottomAction(
                title: step == 3 ? '生成方案' : '下一步',
                showBack: step > 0,
                onBack: () => setState(() => step -= 1),
                onPressed: () {
                  if (step < 3) {
                    setState(() => step += 1);
                  } else {
                    Navigator.of(
                      context,
                    ).push(uzRoute(const BuildResultDemoScreen()));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BuildResultDemoScreen extends StatelessWidget {
  const BuildResultDemoScreen({super.key, this.option});

  final Map<String, dynamic>? option;

  static const parts =
      <
        ({
          IconData icon,
          String category,
          String model,
          String price,
          String badge,
        })
      >[
        (
          icon: Icons.memory_rounded,
          category: 'CPU',
          model: 'Intel Core i5-14600K',
          price: '¥ 1499',
          badge: '全新',
        ),
        (
          icon: Icons.memory_rounded,
          category: '主板',
          model: 'B760M AORUS ELITE',
          price: '¥ 899',
          badge: '全新',
        ),
        (
          icon: Icons.desktop_windows_outlined,
          category: '显卡',
          model: 'RTX 4070 Super 12GB',
          price: '¥ 4399',
          badge: '全新',
        ),
        (
          icon: Icons.view_stream_outlined,
          category: '内存',
          model: 'DDR5 6000 32GB',
          price: '¥ 699',
          badge: '全新',
        ),
        (
          icon: Icons.storage_rounded,
          category: '硬盘',
          model: '1TB PCIe 4.0 SSD',
          price: '¥ 459',
          badge: '全新',
        ),
        (
          icon: Icons.bolt_rounded,
          category: '电源',
          model: '650W 金牌全模组',
          price: '¥ 499',
          badge: '全新',
        ),
        (
          icon: Icons.ac_unit_rounded,
          category: '散热',
          model: '单塔风冷 6 热管',
          price: '¥ 159',
          badge: '全新',
        ),
        (
          icon: Icons.inventory_2_outlined,
          category: '机箱',
          model: 'MATX 白色海景房',
          price: '¥ 399',
          badge: '全新',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final details = option?['details'] as Map<String, dynamic>?;
    final apiParts = (details?['parts'] as List? ?? const <Object>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    final visibleParts = apiParts.isEmpty
        ? parts
        : apiParts.map((part) {
            final role = part['role']?.toString() ?? '';
            final condition = part['condition']?.toString();
            return (
              icon: _iconForRole(role),
              category: _titleForRole(role),
              model: part['name']?.toString() ?? '未知型号',
              price:
                  '¥ ${BuildOptionsDemoScreen._formatPrice((part['reference_price'] as num?)?.round() ?? 0)}',
              badge: condition == 'new' ? '全新' : '二手',
            );
          }).toList();
    final total =
        (option?['estimated_total'] as num?)?.round() ??
        apiParts.fold<int>(
          0,
          (sum, part) =>
              sum + ((part['reference_price'] as num?)?.round() ?? 0),
        );
    final totalText = option == null
        ? '¥8566'
        : '¥${BuildOptionsDemoScreen._formatPrice(total)}';
    final useCase =
        details?['suitable_user']?.toString() ?? '2K 游戏 / 日常剪辑 / 可升级';
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 38,
                    ),
                    icon: const Icon(Icons.chevron_left_rounded, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '配置方案详情',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        useCase,
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _ResultPerformanceCard(),
              const SizedBox(height: 16),
              UzSoftCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '配件清单',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    ...visibleParts.map((part) => _ResultPart(part)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '总计',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalText,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: UzPrimaryButton(
                      title: '保存为图片',
                      icon: Icons.photo_outlined,
                      outlined: true,
                      height: 48,
                      onPressed: () => ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('配置图片已生成'))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: UzPrimaryButton(
                      title: '进入DIY界面编辑',
                      icon: Icons.handyman_outlined,
                      height: 48,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _titleForRole(String role) {
    return switch (role) {
      'cpu' => 'CPU',
      'motherboard' => '主板',
      'gpu' => '显卡',
      'ram' => '内存',
      'storage' => '硬盘',
      'psu' => '电源',
      'cooler' => '散热',
      'case' => '机箱',
      _ => role,
    };
  }

  static IconData _iconForRole(String role) {
    return switch (role) {
      'cpu' => Icons.memory_rounded,
      'motherboard' => Icons.developer_board_outlined,
      'gpu' => Icons.desktop_windows_outlined,
      'ram' => Icons.view_stream_outlined,
      'storage' => Icons.storage_rounded,
      'psu' => Icons.bolt_rounded,
      'cooler' => Icons.ac_unit_rounded,
      'case' => Icons.inventory_2_outlined,
      _ => Icons.memory_rounded,
    };
  }
}

class _ResultPerformanceCard extends StatelessWidget {
  const _ResultPerformanceCard();

  @override
  Widget build(BuildContext context) {
    return UzSoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '游戏性能表现',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 11),
          SizedBox(
            height: 105,
            child: Row(
              children: [
                const Expanded(child: _ResultGauge()),
                const VerticalDivider(indent: 24, endIndent: 24),
                const Expanded(
                  child: _ResultMetric(title: '1080P 电竞', value: '240'),
                ),
                const VerticalDivider(indent: 24, endIndent: 24),
                const Expanded(
                  child: _ResultMetric(title: '4K 高画质', value: '96'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultGauge extends StatelessWidget {
  const _ResultGauge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 108,
          height: 108,
          child: CustomPaint(
            painter: _ResultGaugePainter(),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '168',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500),
                ),
                Text('FPS', style: TextStyle(fontSize: 11)),
                SizedBox(height: 5),
                Text('2K 3A 大作', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = 42.0;
    final track = Paint()
      ..color = const Color(0xFFDDE1E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 0.56,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
        ),
        const Text('FPS', style: TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ResultPart extends StatelessWidget {
  const _ResultPart(this.part);
  final ({
    IconData icon,
    String category,
    String model,
    String price,
    String badge,
  })
  part;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 48, child: Icon(part.icon, size: 27)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      part.category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: part.badge == '二手'
                            ? const Color(0xFFE7F4E8)
                            : const Color(0xFFE8F2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        part.badge,
                        style: TextStyle(
                          color: part.badge == '二手'
                              ? const Color(0xFF3F8B55)
                              : const Color(0xFF1A63B2),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  part.model,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13.5),
                ),
              ],
            ),
          ),
          Text(
            part.price,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
