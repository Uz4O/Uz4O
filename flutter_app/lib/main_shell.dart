import 'dart:ui';

import 'package:flutter/material.dart';

import 'screens/diy_screen.dart';
import 'screens/home_screen.dart';
import 'screens/primary_flows.dart';
import 'screens/profile_screen.dart';
import 'screens/secondary_flows.dart';
import 'screens/styles_screen.dart';
import 'widgets/flow_components.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(onOpenFeature: _openFeature, onOpenStyle: _openStyle),
      StylesScreen(onOpenStyle: _openStyle),
      DiyScreen(onStartDiy: () => _push(const DiyBuilderScreen())),
      ProfileScreen(onAction: _openProfileAction),
    ];
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: pages),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 396),
                  child: _FloatingTabBar(
                    selectedIndex: _selectedIndex,
                    onSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(uzRoute(page));
  }

  void _openFeature(int index) {
    switch (index) {
      case 0:
        _push(const AiBuildScreen());
      case 1:
        _push(const GamePerformanceScreen());
      case 2:
        _push(const ConfigReviewScreen());
      case 3:
        _push(const UpgradePlanScreen());
    }
  }

  void _openStyle(int index) {
    const styles =
        <
          ({
            String title,
            String image,
            String whiteImage,
            String total,
            String whiteTotal,
          })
        >[
          (
            title: '联立 VISION COMPACT',
            image: 'assets/images/style_vision_compact_black.webp',
            whiteImage: 'assets/images/style_vision_compact_white.webp',
            total: '6,520',
            whiteTotal: '6,580',
          ),
          (
            title: 'ROG 创世神 701',
            image: 'assets/images/style_rog_gr701_black.webp',
            whiteImage: 'assets/images/style_rog_gr701_white.webp',
            total: '8,496',
            whiteTotal: '8,596',
          ),
          (
            title: '未知玩家 幻翼',
            image: 'assets/images/style_phantom_wing_black.webp',
            whiteImage: 'assets/images/style_phantom_wing_white.webp',
            total: '3,637',
            whiteTotal: '3,637',
          ),
          (
            title: '乔思伯 BO400',
            image: 'assets/images/style_jonsbo_bo400_black.webp',
            whiteImage: 'assets/images/style_jonsbo_bo400_white.webp',
            total: '4,497',
            whiteTotal: '4,597',
          ),
          (
            title: '星璨辰',
            image: 'assets/images/style_xingcan_chen_black.webp',
            whiteImage: 'assets/images/style_xingcan_chen_white.webp',
            total: '1,884',
            whiteTotal: '1,884',
          ),
          (
            title: '华硕灵光岛 AP202',
            image: 'assets/images/style_catalog_StyleASUSAP202Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleASUSAP202White.webp',
            total: '1,597',
            whiteTotal: '1,647',
          ),
          (
            title: 'HYTE Y70 鱼缸机箱',
            image: 'assets/images/style_catalog_StyleHYTEY70Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleHYTEY70White.webp',
            total: '8,463',
            whiteTotal: '8,563',
          ),
          (
            title: 'AOC 震天弓',
            image: 'assets/images/style_catalog_StyleAOCShockingBowBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleAOCShockingBowWhite.webp',
            total: '1,297',
            whiteTotal: '1,307',
          ),
          (
            title: '乔思伯 BO400CG',
            image: 'assets/images/style_catalog_StyleJonsboBO400CGBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleJonsboBO400CGWhite.webp',
            total: '4,697',
            whiteTotal: '4,797',
          ),
          (
            title: '联力 Vison Min',
            image: 'assets/images/style_catalog_StyleLianLiVisionMinBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleLianLiVisionMinWhite.webp',
            total: '4,388',
            whiteTotal: '4,388',
          ),
          (
            title: '航嘉 S960',
            image: 'assets/images/style_catalog_StyleHangjiaS960Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleHangjiaS960White.webp',
            total: '747',
            whiteTotal: '747',
          ),
          (
            title: '联力 V150INF',
            image: 'assets/images/style_catalog_StyleLianLiV150INFBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleLianLiV150INFWhite.webp',
            total: '1,107',
            whiteTotal: '1,107',
          ),
          (
            title: '乔思伯 TK-1',
            image: 'assets/images/style_catalog_StyleJonsboTK1Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleJonsboTK1White.webp',
            total: '1,118',
            whiteTotal: '1,118',
          ),
          (
            title: '乔思伯 D33 WOOD',
            image: 'assets/images/style_catalog_StyleJonsboD33WoodBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleJonsboD33WoodWhite.webp',
            total: '1,697',
            whiteTotal: '1,697',
          ),
          (
            title: '乔思伯 D34',
            image: 'assets/images/style_catalog_StyleJonsboD34Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleJonsboD34White.webp',
            total: '1,251',
            whiteTotal: '1,311',
          ),
          (
            title: '爱国者 炫影 G20',
            image: 'assets/images/style_catalog_StyleAigoXuanYingG20Black.webp',
            whiteImage:
                'assets/images/style_catalog_StyleAigoXuanYingG20White.webp',
            total: '268',
            whiteTotal: '268',
          ),
          (
            title: '瓦尔基里 VK3',
            image: 'assets/images/style_catalog_StyleValkyrieVK3Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleValkyrieVK3White.webp',
            total: '399',
            whiteTotal: '399',
          ),
          (
            title: '联力 O11 EVO RGB',
            image: 'assets/images/style_catalog_StyleLianLiO11EVORGBBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleLianLiO11EVORGBWhite.webp',
            total: '4,788',
            whiteTotal: '4,788',
          ),
          (
            title: '追风者 EVOLV S2',
            image: 'assets/images/style_catalog_StylePhanteksEvolvS2Black.webp',
            whiteImage:
                'assets/images/style_catalog_StylePhanteksEvolvS2White.webp',
            total: '1,949',
            whiteTotal: '1,949',
          ),
          (
            title: '追风者 EVOLV X2 MATRIX',
            image:
                'assets/images/style_catalog_StylePhanteksEvolvX2MatrixBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StylePhanteksEvolvX2MatrixWhite.webp',
            total: '1,949',
            whiteTotal: '1,949',
          ),
          (
            title: '乔思伯 TK4',
            image: 'assets/images/style_catalog_StyleJonsboTK4Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleJonsboTK4White.webp',
            total: '2,234',
            whiteTotal: '2,234',
          ),
          (
            title: '爱国者 星璨辰 Air',
            image:
                'assets/images/style_catalog_StyleAigoXingcanChenAirBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleAigoXingcanChenAirWhite.webp',
            total: '965',
            whiteTotal: '965',
          ),
          (
            title: '追风者 NV7',
            image: 'assets/images/style_catalog_StylePhanteksNV7Black.webp',
            whiteImage: 'assets/images/style_catalog_StylePhanteksNV7White.webp',
            total: '2,457',
            whiteTotal: '2,457',
          ),
          (
            title: '联力 O11D MINI V2',
            image: 'assets/images/style_catalog_StyleLianLiO11DMiniV2Black.webp',
            whiteImage:
                'assets/images/style_catalog_StyleLianLiO11DMiniV2White.webp',
            total: '1,137',
            whiteTotal: '1,187',
          ),
          (
            title: '华硕 TUF 502 弹药库',
            image: 'assets/images/style_catalog_StyleASUSTUF502AmmoBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleASUSTUF502AmmoWhite.webp',
            total: '3,288',
            whiteTotal: '3,288',
          ),
          (
            title: 'ROG GR801 幻世神',
            image: 'assets/images/style_catalog_StyleROGGR801Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleROGGR801White.webp',
            total: '7,530',
            whiteTotal: '7,630',
          ),
          (
            title: '微星 MPG VIXTA 300R',
            image: 'assets/images/style_catalog_StyleMSIVIXTA300RBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleMSIVIXTA300RWhite.webp',
            total: '1,057',
            whiteTotal: '1,147',
          ),
          (
            title: '航嘉 S960 V2',
            image: 'assets/images/style_catalog_StyleHangjiaS960V2Black.webp',
            whiteImage:
                'assets/images/style_catalog_StyleHangjiaS960V2White.webp',
            total: '248',
            whiteTotal: '258',
          ),
          (
            title: '航嘉 GX750C 挑战者',
            image: 'assets/images/style_catalog_StyleHangjiaGX750CBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleHangjiaGX750CWhite.webp',
            total: '358',
            whiteTotal: '358',
          ),
          (
            title: '酷冷至尊 MF400 Mesh',
            image:
                'assets/images/style_catalog_StyleCoolerMasterMF400MeshBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleCoolerMasterMF400MeshWhite.webp',
            total: '908',
            whiteTotal: '908',
          ),
          (
            title: '鑫谷次元仓 PX',
            image:
                'assets/images/style_catalog_StyleSugonCiyuanCangPXBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleSugonCiyuanCangPXWhite.webp',
            total: '1,264',
            whiteTotal: '1,264',
          ),
          (
            title: '钛坦星舟',
            image: 'assets/images/style_catalog_StyleTitanStarshipBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleTitanStarshipWhite.webp',
            total: '2,346',
            whiteTotal: '2,346',
          ),
          (
            title: '方糖机械大师 酷方 C34PRO',
            image: 'assets/images/style_catalog_StyleFangtangC34ProBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleFangtangC34ProWhite.webp',
            total: '1,667',
            whiteTotal: '1,667',
          ),
          (
            title: '骨伽凌空 V235',
            image: 'assets/images/style_catalog_StyleCougarV235Black.webp',
            whiteImage: 'assets/images/style_catalog_StyleCougarV235White.webp',
            total: '1,037',
            whiteTotal: '1,037',
          ),
          (
            title: '未知玩家 P80 MESH',
            image:
                'assets/images/style_catalog_StyleUnknownPlayerP80MeshBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleUnknownPlayerP80MeshWhite.webp',
            total: '577',
            whiteTotal: '577',
          ),
          (
            title: '七彩虹 C25A',
            image: 'assets/images/style_catalog_StyleColorfulC25ABlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleColorfulC25AWhite.webp',
            total: '1,138',
            whiteTotal: '1,138',
          ),
          (
            title: '爱国者星璨辰 屏显版',
            image:
                'assets/images/style_catalog_StyleXingcanChenScreenBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleXingcanChenScreenWhite.webp',
            total: '1,864',
            whiteTotal: '1,864',
          ),
          (
            title: '玩嘉问界 MIN',
            image: 'assets/images/style_catalog_StyleWanjiaWenjieMinBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleWanjiaWenjieMinWhite.webp',
            total: '398',
            whiteTotal: '398',
          ),
          (
            title: '玩嘉 梦想家副屏版',
            image:
                'assets/images/style_catalog_StyleWanjiaDreamerScreenBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleWanjiaDreamerScreenWhite.webp',
            total: '697',
            whiteTotal: '697',
          ),
          (
            title: '追风者 XT V3 小清风',
            image:
                'assets/images/style_catalog_StylePhanteksXTV3BreezeBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StylePhanteksXTV3BreezeWhite.webp',
            total: '588',
            whiteTotal: '588',
          ),
          (
            title: '航嘉 G63 战戟',
            image: 'assets/images/style_catalog_StyleHangjiaG63WaraxeBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleHangjiaG63WaraxeWhite.webp',
            total: '557',
            whiteTotal: '557',
          ),
          (
            title: '瓦尔基里 VK03-M',
            image: 'assets/images/style_catalog_StyleValkyrieVK03MBlack.webp',
            whiteImage:
                'assets/images/style_catalog_StyleValkyrieVK03MWhite.webp',
            total: '917',
            whiteTotal: '917',
          ),
        ];
    final style = styles[index.clamp(0, styles.length - 1)];
    _push(
      StyleOverviewScreen(
        title: style.title,
        image: style.image,
        whiteImage: style.whiteImage,
        total: style.total,
        whiteTotal: style.whiteTotal,
      ),
    );
  }

  void _openProfileAction(String action) {
    switch (action) {
      case '电脑档案':
        _push(const ComputerProfileScreen());
      case '我的配置单':
        _push(const MyBuildsScreen());
      case '用户协议':
      case '隐私政策':
      case '第三方信息共享清单':
        _push(LegalDocumentScreen(title: action));
      case '联系与投诉':
        _push(const ContactComplaintScreen());
      case '注销账号':
        _push(const AccountDeletionScreen());
    }
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <({String label, IconData icon})>[
    (label: '首页', icon: Icons.home_rounded),
    (label: '风格', icon: Icons.palette_rounded),
    (label: 'DIY', icon: Icons.handyman_rounded),
    (label: '我的', icon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(33),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(33),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 26,
                offset: const Offset(0, 13),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 8) / 4;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 330),
                    curve: Curves.easeOutBack,
                    left: 4 + selectedIndex * itemWidth,
                    top: 4,
                    width: itemWidth,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EBEB).withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.09),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      return Expanded(
                        child: Semantics(
                          label: item.label,
                          selected: selectedIndex == index,
                          button: true,
                          child: InkWell(
                            onTap: () => onSelected(index),
                            borderRadius: BorderRadius.circular(28),
                            child: Center(
                              child: Icon(
                                item.icon,
                                color: Colors.black,
                                size: index == 2 ? 29 : 28,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
