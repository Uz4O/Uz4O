import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzbox_flutter/api/uzbox_api.dart';
import 'package:uzbox_flutter/main.dart';
import 'package:uzbox_flutter/screens/primary_flows.dart';
import 'package:uzbox_flutter/screens/secondary_flows.dart';
import 'package:uzbox_flutter/screens/styles_screen.dart';

void main() {
  testWidgets('DIY shows recommended PSU wattage as the only power metric', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DiyBuilderScreen()));

    expect(find.text('推荐电源瓦数'), findsOneWidget);
    expect(find.text('预计功耗'), findsNothing);
  });

  testWidgets('runs splash, SMS phone login, and home wordmark transition', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authApi = _FakeAuthClient();
    await tester.pumpWidget(UzBoxApp(authApi: authApi));
    expect(find.text('AI 装机助手'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('本机号码一键登录'), findsOneWidget);

    await tester.tap(find.text('我已阅读并同意《用户协议》和《隐私政策》'));
    await tester.pump();
    await tester.tap(find.text('本机号码一键登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('手机号登录'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '824854');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('登录并继续'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('AI 一键装机'), findsOneWidget);
    expect(authApi.accessToken, 'test-access-token');
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders and switches the four main tabs', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const UzBoxApp(skipStartup: true));
    await tester.pumpAndSettle();

    expect(find.text('AI 一键装机'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('风格'));
    await tester.pumpAndSettle();
    expect(find.text('装机风格'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('DIY'));
    await tester.pumpAndSettle();
    expect(find.text('DIY 自由选配'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('我的'));
    await tester.pumpAndSettle();
    expect(find.text('AI 装机助手'), findsOneWidget);
  });

  testWidgets('immersive style panorama supports its core interactions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openedStyle = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: StylesScreen(onOpenStyle: (index) => openedStyle = index),
      ),
    );
    await tester.tap(find.text('沉浸全景'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('沉浸风格'), findsOneWidget);
    expect(find.text('风格全景'), findsOneWidget);
    expect(find.byKey(const ValueKey('immersive-style-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('immersive-style-41')), findsOneWidget);

    await tester.tap(find.text('白色'));
    await tester.pump(const Duration(milliseconds: 650));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('immersive-style-0')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('查看风格'), findsOneWidget);
    expect(find.text('华硕 TUF 502 弹药库'), findsOneWidget);

    await tester.tap(find.text('查看风格'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(openedStyle, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive panorama avoids overflow on Android phone sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final logicalSize in const [Size(360, 800), Size(600, 960)]) {
      tester.view.physicalSize = logicalSize * 3;
      await tester.pumpWidget(const MaterialApp(home: StylesScreen()));
      await tester.tap(find.text('沉浸全景'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('immersive-style-41')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '沉浸全景 $logicalSize');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('opens the primary Flutter flows', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const UzBoxApp(skipStartup: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始装机'));
    await tester.pumpAndSettle();
    expect(find.text('AI 写配置'), findsOneWidget);
    expect(find.text('预算范围'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('联立 VISION COMPACT'));
    await tester.pumpAndSettle();
    expect(find.text('方案介绍'), findsOneWidget);
    expect(find.text('方案配件'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('DIY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始 DIY'));
    await tester.pumpAndSettle();
    expect(find.text('我的装机方案'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的配置单'));
    await tester.pumpAndSettle();
    expect(find.text('管理 AI 生成的配置和现在自己的配置'), findsOneWidget);
  });

  testWidgets('opens matching details for the newly added styles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const UzBoxApp(skipStartup: true));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('风格'));
    await tester.pumpAndSettle();

    const styles = <({String title, String total, String image})>[
      (
        title: '未知玩家 P80 MESH',
        total: '577',
        image:
            'assets/images/style_catalog_StyleUnknownPlayerP80MeshBlack.webp',
      ),
      (
        title: '七彩虹 C25A',
        total: '1,138',
        image: 'assets/images/style_catalog_StyleColorfulC25ABlack.webp',
      ),
      (
        title: '爱国者星璨辰 屏显版',
        total: '1,864',
        image: 'assets/images/style_catalog_StyleXingcanChenScreenBlack.webp',
      ),
      (
        title: '玩嘉问界 MIN',
        total: '398',
        image: 'assets/images/style_catalog_StyleWanjiaWenjieMinBlack.webp',
      ),
      (
        title: '玩嘉 梦想家副屏版',
        total: '697',
        image: 'assets/images/style_catalog_StyleWanjiaDreamerScreenBlack.webp',
      ),
      (
        title: '追风者 XT V3 小清风',
        total: '588',
        image: 'assets/images/style_catalog_StylePhanteksXTV3BreezeBlack.webp',
      ),
      (
        title: '航嘉 G63 战戟',
        total: '557',
        image: 'assets/images/style_catalog_StyleHangjiaG63WaraxeBlack.webp',
      ),
      (
        title: '瓦尔基里 VK03-M',
        total: '917',
        image: 'assets/images/style_catalog_StyleValkyrieVK03MBlack.webp',
      ),
    ];

    for (final style in styles) {
      final styleRow = find.text(style.title);
      await tester.scrollUntilVisible(styleRow, 600);
      await tester.tap(styleRow);
      await tester.pumpAndSettle();

      expect(find.text(style.title), findsWidgets);
      expect(find.text('¥${style.total}'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == style.image,
        ),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('main tabs avoid overflow across Android phone sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final logicalSize in const [
      Size(360, 800),
      Size(412, 915),
      Size(440, 956),
      Size(600, 960),
    ]) {
      tester.view.physicalSize = logicalSize * 3;
      await tester.pumpWidget(const UzBoxApp(skipStartup: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '首页 $logicalSize');

      for (final tab in const ['风格', 'DIY', '我的']) {
        await tester.tap(find.bySemanticsLabel(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab $logicalSize');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('completes review and upgrade result flows', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ConfigReviewScreen()));
    expect(find.text('主要用途'), findsNothing);
    expect(find.text('目标分辨率'), findsNothing);
    await tester.scrollUntilVisible(find.text('填写配置').last, 300);
    await tester.tap(find.text('填写配置').last);
    await tester.pumpAndSettle();
    expect(find.text('填写配置'), findsWidgets);
    expect(find.text('价格'), findsNothing);
    expect(find.text('主要用途'), findsNothing);
    expect(find.text('目标分辨率'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        key: ValueKey('review-result-test'),
        home: ConfigReviewResultScreen(
          result: {
            'risk_level': 'warning',
            'summary': '搭配存在一处明显短板，建议调整后再购买。',
            'reply_text': '请把 CPU 调整到与显卡匹配的档次。',
            'pairing_rating': {'status': 'graded', 'grade': 'C'},
            'performance_rating': {'status': 'graded', 'grade': 'A'},
            'recommendations': [
              {
                'severity': 'recommended',
                'title': '缩小 CPU 与显卡的档次差距',
                'reason': 'CPU 明显弱于显卡。',
                'action': '只调整 CPU 或显卡其中一项。',
                'expected_impact': '减少核心性能短板。',
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('综合结论'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.textContaining('怎么改：'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        key: ValueKey('legacy-review-result-test'),
        home: ConfigReviewResultScreen(
          result: {
            'risk_level': 'error',
            'summary': '旧服务认为商家报价偏高。',
            'reply_text': '旧价格回复。',
            'findings': [
              {
                'level': 'error',
                'code': 'seller_price_gap',
                'title': '商家报价偏高',
                'detail': '旧价格结论',
              },
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('商家报价偏高'), findsNothing);
    expect(find.text('待补全'), findsNWidgets(2));

    await tester.pumpWidget(
      const MaterialApp(
        key: ValueKey('upgrade-test'),
        home: UpgradePlanScreen(),
      ),
    );
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.text('帮我找短板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生成升级方案'));
    await tester.pumpAndSettle();
    expect(find.text('升级顺序'), findsOneWidget);
  });

  testWidgets('core flows avoid overflow on compact and wide screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final screens = <Widget>[
      const AiBuildScreen(),
      const ConfigReviewScreen(),
      const UpgradePlanScreen(),
      const GamePerformanceScreen(),
      const DiyBuilderScreen(),
      const ComputerProfileScreen(),
      const BuildResultDemoScreen(),
    ];
    for (final logicalSize in const [Size(360, 800), Size(600, 960)]) {
      tester.view.physicalSize = logicalSize * 3;
      for (final screen in screens) {
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} $logicalSize',
        );
      }
    }
  });

  testWidgets('renders performance and build result details', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PerformanceResultScreen(
          games: [(title: '瓦罗兰特', asset: 'assets/images/game_valorant.png')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Time Spy 显卡分数'), findsOneWidget);
    expect(find.text('预计平均帧率'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: BuildResultDemoScreen()));
    await tester.pumpAndSettle();
    expect(find.text('配置方案详情'), findsOneWidget);
    expect(find.text('¥8566'), findsOneWidget);
  });
}

class _FakeAuthClient implements UzBoxAuthClient {
  @override
  String? accessToken;

  @override
  Future<UzBoxSmsResult> sendSmsCode(String phone) async {
    expect(phone, '13800138000');
    return const UzBoxSmsResult(sent: true, debugCode: '824854');
  }

  @override
  Future<UzBoxAuthSession> loginWithSmsCode({
    required String phone,
    required String code,
  }) async {
    expect(phone, '13800138000');
    expect(code, '824854');
    const session = UzBoxAuthSession(
      accessToken: 'test-access-token',
      tokenType: 'bearer',
      account: UzBoxAccount(
        id: 'test-account',
        phone: '13800138000',
        nickname: '测试用户',
      ),
    );
    accessToken = session.accessToken;
    return session;
  }

  @override
  Future<UzBoxAccount> currentAccount() async => const UzBoxAccount(
    id: 'test-account',
    phone: '13800138000',
    nickname: '测试用户',
  );

  @override
  void clearSession() => accessToken = null;
}
