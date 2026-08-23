import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../explorer_asset_geometry.dart';
import '../style_explorer_projection.dart';

class _StyleShowcase {
  const _StyleShowcase(
    this.title,
    this.cost,
    this.image,
    this.height, {
    this.imageScale = 1,
    this.imageYOffset = 0,
  });

  final String title;
  final String cost;
  final String image;
  final double height;
  final double imageScale;
  final double imageYOffset;

  String get whiteImage {
    const overrides = {
      'assets/images/style_vision_compact_black.webp':
          'assets/images/style_vision_compact_white.webp',
      'assets/images/style_rog_gr701_black.webp':
          'assets/images/style_rog_gr701_white.webp',
      'assets/images/style_phantom_wing_black.webp':
          'assets/images/style_phantom_wing_white.webp',
      'assets/images/style_jonsbo_bo400_black.webp':
          'assets/images/style_jonsbo_bo400_white.webp',
      'assets/images/style_xingcan_chen_black.webp':
          'assets/images/style_xingcan_chen_white.webp',
      'assets/images/style_catalog_StyleASUSTUF502AmmoBlack.webp':
          'assets/images/style_catalog_StyleASUSTUF502AmmoWhite.webp',
    };
    return overrides[image] ?? image.replaceFirst('Black', 'White');
  }

  String get explorerImage => _explorerPath(image);

  String get whiteExplorerImage => _explorerPath(whiteImage);

  static String _explorerPath(String source) {
    final filename = source.substring(source.lastIndexOf('/') + 1);
    final stem = filename.substring(0, filename.lastIndexOf('.'));
    return 'assets/images/explorer/$stem.webp';
  }
}

class StylesScreen extends StatelessWidget {
  const StylesScreen({super.key, this.onOpenStyle});

  final ValueChanged<int>? onOpenStyle;

  static Future<void> openImmersive(
    BuildContext context, {
    ValueChanged<int>? onOpenStyle,
  }) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: _ImmersiveStyleExplorer(
          styles: _styles,
          onOpenStyle: (index) {
            Navigator.of(context).pop();
            onOpenStyle?.call(index);
          },
        ),
      ),
    ),
  );

  static const _styles = <_StyleShowcase>[
    _StyleShowcase(
      '联立 VISION\nCOMPACT',
      '2,735',
      'assets/images/style_vision_compact_black.webp',
      178,
      imageScale: 1.10,
    ),
    _StyleShowcase(
      'ROG 创世神 701',
      '3,476',
      'assets/images/style_rog_gr701_black.webp',
      172,
      imageScale: 1.04,
      imageYOffset: -6,
    ),
    _StyleShowcase(
      '未知玩家 幻翼',
      '1,257',
      'assets/images/style_phantom_wing_black.webp',
      172,
      imageScale: 1.03,
      imageYOffset: -8,
    ),
    _StyleShowcase(
      '乔思伯 BO400',
      '1,663',
      'assets/images/style_jonsbo_bo400_black.webp',
      142,
      imageScale: 1.04,
      imageYOffset: -4,
    ),
    _StyleShowcase(
      '星璨辰',
      '1,363',
      'assets/images/style_xingcan_chen_black.webp',
      150,
      imageScale: 0.94,
      imageYOffset: -4,
    ),
    _StyleShowcase(
      '华硕灵光岛 AP202',
      '1,138',
      'assets/images/style_catalog_StyleASUSAP202Black.webp',
      158,
    ),
    _StyleShowcase(
      'HYTE Y70 鱼缸机箱',
      '3,485',
      'assets/images/style_catalog_StyleHYTEY70Black.webp',
      170,
    ),
    _StyleShowcase(
      'AOC 震天弓',
      '748',
      'assets/images/style_catalog_StyleAOCShockingBowBlack.webp',
      160,
    ),
    _StyleShowcase(
      '乔思伯 BO400CG',
      '2,663',
      'assets/images/style_catalog_StyleJonsboBO400CGBlack.webp',
      160,
    ),
    _StyleShowcase(
      '联力 Vison Min',
      '2,134',
      'assets/images/style_catalog_StyleLianLiVisionMinBlack.webp',
      160,
    ),
    _StyleShowcase(
      '航嘉 S960',
      '747',
      'assets/images/style_catalog_StyleHangjiaS960Black.webp',
      160,
    ),
    _StyleShowcase(
      '联力 V150INF',
      '1,107',
      'assets/images/style_catalog_StyleLianLiV150INFBlack.webp',
      160,
    ),
    _StyleShowcase(
      '乔思伯 TK-1',
      '1,118',
      'assets/images/style_catalog_StyleJonsboTK1Black.webp',
      160,
    ),
    _StyleShowcase(
      '乔思伯 D33 WOOD',
      '1,697',
      'assets/images/style_catalog_StyleJonsboD33WoodBlack.webp',
      160,
    ),
    _StyleShowcase(
      '乔思伯 D34',
      '1,251',
      'assets/images/style_catalog_StyleJonsboD34Black.webp',
      160,
    ),
    _StyleShowcase(
      '爱国者 炫影 G20',
      '268',
      'assets/images/style_catalog_StyleAigoXuanYingG20Black.webp',
      160,
    ),
    _StyleShowcase(
      '瓦尔基里 VK3',
      '399',
      'assets/images/style_catalog_StyleValkyrieVK3Black.webp',
      160,
    ),
    _StyleShowcase(
      '联力 O11 EVO RGB',
      '4,788',
      'assets/images/style_catalog_StyleLianLiO11EVORGBBlack.webp',
      170,
    ),
    _StyleShowcase(
      '追风者 EVOLV S2',
      '1,949',
      'assets/images/style_catalog_StylePhanteksEvolvS2Black.webp',
      160,
    ),
    _StyleShowcase(
      '追风者 EVOLV X2 MATRIX',
      '1,949',
      'assets/images/style_catalog_StylePhanteksEvolvX2MatrixBlack.webp',
      170,
    ),
    _StyleShowcase(
      '乔思伯 TK4',
      '2,234',
      'assets/images/style_catalog_StyleJonsboTK4Black.webp',
      160,
    ),
    _StyleShowcase(
      '爱国者 星璨辰 Air',
      '965',
      'assets/images/style_catalog_StyleAigoXingcanChenAirBlack.webp',
      160,
    ),
    _StyleShowcase(
      '追风者 NV7',
      '2,457',
      'assets/images/style_catalog_StylePhanteksNV7Black.webp',
      170,
    ),
    _StyleShowcase(
      '联力 O11D MINI V2',
      '1,137',
      'assets/images/style_catalog_StyleLianLiO11DMiniV2Black.webp',
      160,
    ),
    _StyleShowcase(
      '华硕 TUF 502 弹药库',
      '3,288',
      'assets/images/style_catalog_StyleASUSTUF502AmmoBlack.webp',
      170,
    ),
    _StyleShowcase(
      'ROG GR801 幻世神',
      '7,530',
      'assets/images/style_catalog_StyleROGGR801Black.webp',
      180,
    ),
    _StyleShowcase(
      '微星 MPG VIXTA 300R',
      '1,057',
      'assets/images/style_catalog_StyleMSIVIXTA300RBlack.webp',
      160,
    ),
    _StyleShowcase(
      '航嘉 S960 V2',
      '248',
      'assets/images/style_catalog_StyleHangjiaS960V2Black.webp',
      160,
    ),
    _StyleShowcase(
      '航嘉 GX750C 挑战者',
      '358',
      'assets/images/style_catalog_StyleHangjiaGX750CBlack.webp',
      160,
    ),
    _StyleShowcase(
      '酷冷至尊 MF400 Mesh',
      '908',
      'assets/images/style_catalog_StyleCoolerMasterMF400MeshBlack.webp',
      160,
    ),
    _StyleShowcase(
      '鑫谷次元仓 PX',
      '1,264',
      'assets/images/style_catalog_StyleSugonCiyuanCangPXBlack.webp',
      160,
    ),
    _StyleShowcase(
      '钛坦星舟',
      '2,346',
      'assets/images/style_catalog_StyleTitanStarshipBlack.webp',
      160,
    ),
    _StyleShowcase(
      '方糖机械大师 酷方 C34PRO',
      '1,667',
      'assets/images/style_catalog_StyleFangtangC34ProBlack.webp',
      170,
    ),
    _StyleShowcase(
      '骨伽凌空 V235',
      '1,037',
      'assets/images/style_catalog_StyleCougarV235Black.webp',
      160,
    ),
    _StyleShowcase(
      '未知玩家 P80 MESH',
      '577',
      'assets/images/style_catalog_StyleUnknownPlayerP80MeshBlack.webp',
      160,
    ),
    _StyleShowcase(
      '七彩虹 C25A',
      '1,138',
      'assets/images/style_catalog_StyleColorfulC25ABlack.webp',
      160,
    ),
    _StyleShowcase(
      '爱国者星璨辰 屏显版',
      '1,864',
      'assets/images/style_catalog_StyleXingcanChenScreenBlack.webp',
      160,
    ),
    _StyleShowcase(
      '玩嘉问界 MIN',
      '398',
      'assets/images/style_catalog_StyleWanjiaWenjieMinBlack.webp',
      160,
    ),
    _StyleShowcase(
      '玩嘉 梦想家副屏版',
      '697',
      'assets/images/style_catalog_StyleWanjiaDreamerScreenBlack.webp',
      160,
    ),
    _StyleShowcase(
      '追风者 XT V3 小清风',
      '588',
      'assets/images/style_catalog_StylePhanteksXTV3BreezeBlack.webp',
      160,
    ),
    _StyleShowcase(
      '航嘉 G63 战戟',
      '557',
      'assets/images/style_catalog_StyleHangjiaG63WaraxeBlack.webp',
      160,
    ),
    _StyleShowcase(
      '瓦尔基里 VK03-M',
      '917',
      'assets/images/style_catalog_StyleValkyrieVK03MBlack.webp',
      160,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.12,
            colors: [Colors.white, Color(0xFFF3F7F9)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth - 40, 430.0);
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 105),
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '装机风格',
                                    style: TextStyle(
                                      fontFamily: '.SF Pro Display',
                                      color: Color(0xFF090D11),
                                      fontSize: 29,
                                      height: 1.17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '多种高性能整机设计，找到属于你的风格',
                                    style: TextStyle(
                                      color: Color(0xFF7A828E),
                                      fontSize: 11,
                                      height: 1.27,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _ImmersiveButton(
                              onTap: () => openImmersive(
                                context,
                                onOpenStyle: onOpenStyle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(
                          _styles.length,
                          (index) => _ShowcaseRow(
                            index: index,
                            style: _styles[index],
                            onTap: () => onOpenStyle?.call(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ImmersiveStyleExplorer extends StatefulWidget {
  const _ImmersiveStyleExplorer({
    required this.styles,
    required this.onOpenStyle,
  });

  final List<_StyleShowcase> styles;
  final ValueChanged<int> onOpenStyle;

  @override
  State<_ImmersiveStyleExplorer> createState() =>
      _ImmersiveStyleExplorerState();
}

class _ImmersiveStyleExplorerState extends State<_ImmersiveStyleExplorer>
    with TickerProviderStateMixin {
  static const _itemCount = 42;
  static const _overviewCenter = Offset(0, 1.2);

  late final AnimationController _topologyController;
  late final AnimationController _entranceController;
  late final AnimationController _selectionController;
  late final AnimationController _colorController;
  late final Ticker _sceneTicker;
  double _tileSize = 1.65;
  double _spacingX = 2.45;
  double _spacingY = 2.45;
  double _overviewCameraZ = 34;
  double _focusCameraZ = 12;
  double _fieldOfView = 45;
  double _curvature = .14;
  double _dragSpeed = 2.2;
  double _positionDamping = .2;
  double _zoomDamping = .25;
  double _tiltStrength = .08;
  double _dragResistance = .25;
  double _cameraZ = 34;
  double _renderCameraZ = 34;
  double _gestureStartCameraZ = 34;
  Offset _contentPosition = _overviewCenter;
  Offset _renderContentPosition = _overviewCenter;
  Offset _gestureStartContentPosition = _overviewCenter;
  Offset _gestureStartFocalPoint = Offset.zero;
  double _targetTiltX = 0;
  double _targetTiltY = 0;
  double _renderTiltX = 0;
  double _renderTiltY = 0;
  int? _selectedItem;
  int? _selectionTransitionItem;
  bool _usesWhite = false;
  bool _colorTransitioning = false;
  bool? _previousUsesWhite;
  bool _showsTuning = false;
  Duration? _lastSceneTick;

  bool get _isZoomedIn => _cameraZ <= _focusCameraZ + 2;

  @override
  void initState() {
    super.initState();
    _topologyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 42),
    )..repeat();
    // SceneKit mounts five nodes per display frame, starting them at z = -10
    // with a short fade/scale.  Keep the same cadence in Flutter so the first
    // frame is not a fully formed, flat wall of hardware.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1_200),
    )..addListener(_markAnimated);
    _selectionController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 480),
            reverseDuration: const Duration(milliseconds: 380),
          )
          ..addListener(_markAnimated)
          ..addStatusListener(_selectionAnimationStatusChanged);
    _colorController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1_200),
          )
          ..addListener(_markAnimated)
          ..addStatusListener(_colorAnimationStatusChanged);
    _sceneTicker = createTicker(_advanceScene);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entranceController.forward();
      _wakeSceneTicker();
    });
  }

  @override
  void dispose() {
    _sceneTicker.dispose();
    _topologyController.dispose();
    _entranceController.dispose();
    _selectionController.dispose();
    _colorController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
    super.dispose();
  }

  void _markAnimated() {
    if (mounted) setState(() {});
  }

  void _selectionAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() => _selectionTransitionItem = null);
    }
  }

  void _colorAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _colorTransitioning = false;
        _previousUsesWhite = null;
      });
    }
  }

  void _wakeSceneTicker() {
    _lastSceneTick = null;
    if (!_sceneTicker.isActive) _sceneTicker.start();
  }

  void _advanceScene(Duration elapsed) {
    final previous = _lastSceneTick;
    _lastSceneTick = elapsed;
    final delta = previous == null
        ? 1 / 60
        : ((elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond)
              .clamp(1 / 120, 1 / 30);
    final positionBlend =
        1 - math.exp(-delta / math.max(_positionDamping, .001));
    final zoomBlend = 1 - math.exp(-delta / math.max(_zoomDamping, .001));
    _renderContentPosition = Offset(
      _renderContentPosition.dx +
          (_contentPosition.dx - _renderContentPosition.dx) * positionBlend,
      _renderContentPosition.dy +
          (_contentPosition.dy - _renderContentPosition.dy) * positionBlend,
    );
    _renderCameraZ += (_cameraZ - _renderCameraZ) * zoomBlend;
    _renderTiltX += (_targetTiltX - _renderTiltX) * positionBlend;
    _renderTiltY += (_targetTiltY - _renderTiltY) * positionBlend;

    final positionSettled =
        (_contentPosition - _renderContentPosition).distance < .001;
    final zoomSettled = (_cameraZ - _renderCameraZ).abs() < .001;
    final tiltSettled =
        (_targetTiltX - _renderTiltX).abs() < .001 &&
        (_targetTiltY - _renderTiltY).abs() < .001;
    if (positionSettled && zoomSettled && tiltSettled) {
      _renderContentPosition = _contentPosition;
      _renderCameraZ = _cameraZ;
      _renderTiltX = _targetTiltX;
      _renderTiltY = _targetTiltY;
      _lastSceneTick = null;
      _sceneTicker.stop();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _TopologyBackground(
            controller: _topologyController,
            opacity: _isZoomedIn ? .55 : 1,
          ),
          LayoutBuilder(builder: _buildScene),
          if (_selectedItem == null) _buildHeader(),
          if (_selectedItem != null)
            LayoutBuilder(
              builder: (_, constraints) =>
                  _buildFocusOverlay(constraints.biggest),
            ),
          if (_showsTuning && _selectedItem == null) _buildTuningPanel(),
          _buildBottomControl(),
        ],
      ),
    );
  }

  Widget _buildScene(BuildContext context, BoxConstraints constraints) {
    final size = constraints.biggest;
    final entranceElapsed = _entranceController.value * 1.2;
    final selectionProgress = Curves.easeInOut.transform(
      _selectionController.value,
    );
    final transitionItem = _selectionTransitionItem;
    final projection = StyleExplorerProjection(
      size,
      cameraZ: _renderCameraZ,
      contentPositionWorld: _renderContentPosition,
      fieldOfViewDegrees: _fieldOfView,
      curvatureStrength: _curvature,
      minimumZoom: _focusCameraZ,
      maximumZoom: _overviewCameraZ,
      gridSpacingX: _spacingX,
      gridSpacingY: _spacingY,
    );
    final layouts =
        List.generate(_itemCount, (itemIndex) {
          final selected = itemIndex == _selectedItem;
          final selectionTargetDepth = transitionItem == null
              ? 0.0
              : transitionItem == itemIndex
              ? 2.0
              : -.5;
          final selectionDepth = selectionTargetDepth * selectionProgress;
          final entryMove = _entryMove(itemIndex, entranceElapsed);
          final entryScaleProgress = _entryScale(itemIndex, entranceElapsed);
          final entryOpacity = _entryOpacity(itemIndex, entranceElapsed);
          final entryDepth = -10 * (1 - entryMove);
          final depthOffset = selectionDepth + entryDepth;
          final projected = projection.project(
            itemIndex,
            depthOffset: depthOffset,
          );
          final entryScale = .64 + (.36 * entryScaleProgress);
          final selectionScaleTarget = transitionItem == null
              ? 1.0
              : transitionItem == itemIndex
              ? 1.5
              : .52;
          final selectionScale =
              1 + (selectionScaleTarget - 1) * selectionProgress;
          final selectionOpacityTarget = transitionItem == null
              ? 1.0
              : transitionItem == itemIndex
              ? 1.0
              : .14;
          final selectionOpacity =
              1 + (selectionOpacityTarget - 1) * selectionProgress;
          return _ExplorerLayoutNode(
            itemIndex: itemIndex,
            styleIndex: _styleIndexForItem(itemIndex),
            projected: projected,
            depthOffset: depthOffset,
            scale: entryScale * selectionScale,
            opacity: entryOpacity * selectionOpacity,
            selected: selected,
          );
        })..sort((left, right) {
          if (left.selected != right.selected) return left.selected ? 1 : -1;
          return right.projected.distance.compareTo(left.projected.distance);
        });

    final children = <Widget>[];
    for (final layout in layouts) {
      final style = widget.styles[layout.styleIndex];
      children.addAll(
        _buildExplorerNodeWidgets(
          layout: layout,
          style: style,
          projection: projection,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _selectedItem == null ? null : () => setState(_clearSelection),
      onScaleStart: (details) {
        setState(() {
          _clearSelection();
          _targetTiltX = 0;
          _targetTiltY = 0;
          _gestureStartCameraZ = _cameraZ;
          _gestureStartContentPosition = _contentPosition;
          _gestureStartFocalPoint = details.focalPoint;
        });
      },
      onScaleUpdate: (details) {
        final nextCameraZ = (_gestureStartCameraZ / details.scale).clamp(
          _focusCameraZ,
          _overviewCameraZ,
        );
        final focalDelta = details.focalPoint - _gestureStartFocalPoint;
        final visibleHeight = _visibleHeight(nextCameraZ);
        final worldPerPoint =
            visibleHeight / math.max(size.height, 1) * _dragSpeed;
        final nextPosition =
            _gestureStartContentPosition +
            Offset(
              focalDelta.dx * worldPerPoint,
              -focalDelta.dy * worldPerPoint,
            );
        final tiltScale = math.min(1.0, _focusCameraZ / nextCameraZ);
        setState(() {
          _cameraZ = nextCameraZ;
          _contentPosition = _clampedContentPosition(
            nextPosition,
            size,
            nextCameraZ,
            allowsResistance: true,
          );
          _targetTiltX =
              (-focalDelta.dy * worldPerPoint * _tiltStrength * tiltScale)
                  .clamp(-.14, .14);
          _targetTiltY =
              (focalDelta.dx * worldPerPoint * _tiltStrength * tiltScale).clamp(
                -.14,
                .14,
              );
        });
        _wakeSceneTicker();
      },
      onScaleEnd: (_) {
        setState(() {
          _targetTiltX = 0;
          _targetTiltY = 0;
          if (_cameraZ > _focusCameraZ + 2) {
            _contentPosition = _overviewCenter;
          } else {
            _contentPosition = _clampedContentPosition(
              _contentPosition,
              size,
              _cameraZ,
            );
          }
        });
        _wakeSceneTicker();
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0008)
          ..rotateX(_renderTiltX)
          ..rotateY(_renderTiltY),
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }

  List<Widget> _buildExplorerNodeWidgets({
    required _ExplorerLayoutNode layout,
    required _StyleShowcase style,
    required StyleExplorerProjection projection,
  }) {
    final widgets = <Widget>[];

    void onTap() => _selectItem(layout.itemIndex);

    if (_colorTransitioning && _previousUsesWhite != null) {
      final elapsed = _colorController.value * 1.2;
      final enterProgress = _easeProgress(
        elapsed,
        _colorDelay(layout.itemIndex, incoming: true),
        .68,
        Curves.easeOut,
      );
      final enterOpacity = _linearProgress(
        elapsed,
        _colorDelay(layout.itemIndex, incoming: true),
        .58,
      );
      final exitProgress = _easeProgress(
        elapsed,
        _colorDelay(layout.itemIndex, incoming: false),
        .5,
        Curves.easeIn,
      );
      final exitOpacity =
          1 -
          _linearProgress(
            elapsed,
            _colorDelay(layout.itemIndex, incoming: false),
            .28,
          );
      final normalizedY =
          _gridY(layout.itemIndex) /
          (StyleExplorerProjection.rows * _spacingY / 2);
      final incoming = projection.project(
        layout.itemIndex,
        depthOffset: layout.depthOffset - 18 * (1 - enterProgress),
        worldOffset: Offset(0, normalizedY * (1 - enterProgress)),
      );
      final outgoing = projection.project(
        layout.itemIndex,
        depthOffset: layout.depthOffset + 12 * exitProgress,
        worldOffset: Offset(0, normalizedY * .5 * exitProgress),
      );
      widgets.add(
        _positionedExplorerImage(
          key: ValueKey('immersive-style-${layout.itemIndex}'),
          style: style,
          projected: incoming,
          nodeScale: layout.scale,
          path: _usesWhite ? style.whiteExplorerImage : style.explorerImage,
          opacity: layout.opacity * enterOpacity,
          onTap: onTap,
        ),
      );
      widgets.add(
        _positionedExplorerImage(
          key: ValueKey('immersive-style-${layout.itemIndex}-outgoing'),
          style: style,
          projected: outgoing,
          nodeScale: layout.scale,
          path: _previousUsesWhite == true
              ? style.whiteExplorerImage
              : style.explorerImage,
          opacity: layout.opacity * exitOpacity,
          onTap: onTap,
          ignorePointer: true,
        ),
      );
      return widgets;
    }

    final path = _usesWhite ? style.whiteExplorerImage : style.explorerImage;
    widgets.add(
      _positionedExplorerImage(
        key: ValueKey('immersive-style-${layout.itemIndex}'),
        style: style,
        projected: layout.projected,
        nodeScale: layout.scale,
        path: path,
        opacity: layout.opacity,
        onTap: onTap,
      ),
    );
    return widgets;
  }

  Widget _positionedExplorerImage({
    required Key key,
    required _StyleShowcase style,
    required StyleExplorerProjectedNode projected,
    required double nodeScale,
    required String path,
    required double opacity,
    required VoidCallback onTap,
    bool ignorePointer = false,
  }) {
    final placement = _imagePlacement(
      style: style,
      projected: projected,
      nodeScale: nodeScale,
      assetPath: path,
    );
    return Positioned(
      key: key,
      left: placement.imageRect.left,
      top: placement.imageRect.top,
      width: placement.imageRect.width,
      height: placement.imageRect.height,
      child: IgnorePointer(
        ignoring: ignorePointer,
        child: Opacity(
          opacity: opacity.clamp(0, 1),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
            child: Image.asset(
              path,
              fit: placement.fillCanvas ? BoxFit.fill : BoxFit.contain,
              width: placement.imageRect.width,
              height: placement.imageRect.height,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }

  double _entryMove(int itemIndex, double elapsed) {
    final batch = itemIndex ~/ 5;
    final slot = itemIndex % 5;
    final delay = batch * (1 / 60) + slot * .014;
    return _easeProgress(elapsed, delay, .58, Curves.easeOut);
  }

  double _entryScale(int itemIndex, double elapsed) {
    final batch = itemIndex ~/ 5;
    final slot = itemIndex % 5;
    final delay = batch * (1 / 60) + slot * .014;
    return _easeProgress(elapsed, delay, .5, Curves.easeOut);
  }

  double _entryOpacity(int itemIndex, double elapsed) {
    final batch = itemIndex ~/ 5;
    final slot = itemIndex % 5;
    final delay = batch * (1 / 60) + slot * .014;
    return _linearProgress(elapsed, delay, .36);
  }

  double _gridY(int itemIndex) {
    final row = itemIndex ~/ StyleExplorerProjection.columns;
    return ((StyleExplorerProjection.rows - 1) / 2 - row) * _spacingY;
  }

  double _colorDelay(int itemIndex, {required bool incoming}) {
    // Swift uses a random delay for each clone. A stable hash gives the same
    // organic stagger on every platform while keeping screenshots repeatable.
    final seed = incoming ? 0x45D9F3B : 0x9E3779B9;
    final value = ((itemIndex * 1103515245 + seed) & 0x7fffffff) / 0x7fffffff;
    return value * (incoming ? .4 : .3);
  }

  double _linearProgress(double elapsed, double delay, double duration) {
    return ((elapsed - delay) / duration).clamp(0.0, 1.0);
  }

  double _easeProgress(
    double elapsed,
    double delay,
    double duration,
    Curve curve,
  ) {
    return curve.transform(_linearProgress(elapsed, delay, duration));
  }

  _ExplorerImagePlacement _imagePlacement({
    required _StyleShowcase style,
    required StyleExplorerProjectedNode projected,
    required double nodeScale,
    required String assetPath,
  }) {
    final targetSide =
        projected.visibleMaxSide(tileSize: _tileSize) * nodeScale;
    final baseline = targetSide * .44;
    if (style.title != '瓦尔基里 VK03-M') {
      final imageRect = Rect.fromLTWH(
        projected.center.dx - targetSide / 2,
        projected.center.dy + baseline - targetSide,
        targetSide,
        targetSide,
      );
      final aspect = ExplorerAssetGeometry.aspectRatio(assetPath);
      final visibleWidth = aspect >= 1 ? targetSide : targetSide * aspect;
      final visibleHeight = aspect >= 1 ? targetSide / aspect : targetSide;
      return _ExplorerImagePlacement(
        imageRect: imageRect,
        visibleFrame: Rect.fromLTWH(
          imageRect.left + (targetSide - visibleWidth) / 2,
          imageRect.bottom - visibleHeight,
          visibleWidth,
          visibleHeight,
        ),
        fillCanvas: false,
      );
    }

    final geometry = assetPath == style.whiteExplorerImage
        ? _ExplorerCanvasGeometry.vk03White
        : _ExplorerCanvasGeometry.vk03Black;
    final pixelsToPoints =
        targetSide /
        math.max(geometry.visibleBounds.width, geometry.visibleBounds.height);
    final imageRect = Rect.fromLTWH(
      projected.center.dx -
          (geometry.visibleBounds.left + geometry.visibleBounds.width / 2) *
              pixelsToPoints,
      projected.center.dy +
          baseline -
          geometry.visibleBounds.bottom * pixelsToPoints,
      geometry.canvasSize.width * pixelsToPoints,
      geometry.canvasSize.height * pixelsToPoints,
    );
    return _ExplorerImagePlacement(
      imageRect: imageRect,
      visibleFrame: Rect.fromLTWH(
        projected.center.dx - geometry.visibleBounds.width * pixelsToPoints / 2,
        projected.center.dy +
            baseline -
            geometry.visibleBounds.height * pixelsToPoints,
        geometry.visibleBounds.width * pixelsToPoints,
        geometry.visibleBounds.height * pixelsToPoints,
      ),
      fillCanvas: true,
    );
  }

  void _selectItem(int itemIndex) {
    if (_selectedItem == itemIndex) {
      setState(_clearSelection);
      _wakeSceneTicker();
      return;
    }
    setState(() {
      _selectionTransitionItem = itemIndex;
      _selectedItem = itemIndex;
      _showsTuning = false;
      _cameraZ = _focusCameraZ;
      _contentPosition = -_gridWorldPosition(itemIndex);
      _targetTiltX = 0;
      _targetTiltY = 0;
    });
    _selectionController.forward(from: 0);
    _wakeSceneTicker();
  }

  void _clearSelection() {
    if (_selectedItem == null && _selectionTransitionItem == null) return;
    _selectedItem = null;
    if (_selectionTransitionItem != null) {
      _selectionController.reverse();
    }
  }

  int _styleIndexForItem(int itemIndex) {
    return itemIndex % widget.styles.length;
  }

  Offset _gridWorldPosition(int itemIndex) {
    final column = itemIndex % StyleExplorerProjection.columns;
    final row = itemIndex ~/ StyleExplorerProjection.columns;
    return Offset(
      (column - (StyleExplorerProjection.columns - 1) / 2) * _spacingX,
      ((StyleExplorerProjection.rows - 1) / 2 - row) * _spacingY,
    );
  }

  double _visibleHeight(double cameraZ) =>
      2 * math.tan(_fieldOfView * math.pi / 360) * cameraZ;

  Offset _clampedContentPosition(
    Offset value,
    Size size,
    double cameraZ, {
    bool allowsResistance = false,
  }) {
    final gridHalfWidth = StyleExplorerProjection.columns * _spacingX / 2;
    final gridHalfHeight = StyleExplorerProjection.rows * _spacingY / 2;
    final visibleHeight = _visibleHeight(cameraZ);
    final visibleWidth = visibleHeight * size.width / math.max(size.height, 1);
    final limitX = math.max(0.0, gridHalfWidth - visibleWidth / 2 + 2);
    final limitY = math.max(0.0, gridHalfHeight - visibleHeight / 2 + 2);
    double resist(double input, double limit) {
      if (!allowsResistance) return input.clamp(-limit, limit);
      final resisted = input > limit
          ? limit + (input - limit) * _dragResistance
          : input < -limit
          ? -limit + (input + limit) * _dragResistance
          : input;
      return resisted.clamp(-limit - 3, limit + 3);
    }

    return Offset(resist(value.dx, limitX), resist(value.dy, limitY));
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 1.67),
                    child: const Text(
                      '沉浸风格',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Transform.translate(
                    offset: const Offset(.33, .67),
                    child: const Text(
                      '风格全景',
                      style: TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 12,
                        letterSpacing: -.42,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _ExplorerCircleButton(
                icon: CupertinoIcons.slider_horizontal_3,
                semanticLabel: '调整沉浸风格参数',
                onTap: () => setState(() => _showsTuning = !_showsTuning),
              ),
              const SizedBox(width: 8),
              _ExplorerCircleButton(
                icon: CupertinoIcons.xmark,
                semanticLabel: '退出沉浸风格浏览',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusOverlay(Size size) {
    final itemIndex = _selectedItem!;
    final style = widget.styles[_styleIndexForItem(itemIndex)];
    final projection = StyleExplorerProjection(
      size,
      cameraZ: _renderCameraZ,
      contentPositionWorld: _renderContentPosition,
      fieldOfViewDegrees: _fieldOfView,
      curvatureStrength: _curvature,
      minimumZoom: _focusCameraZ,
      maximumZoom: _overviewCameraZ,
      gridSpacingX: _spacingX,
      gridSpacingY: _spacingY,
    );
    final node = projection.project(itemIndex, depthOffset: 2);
    final visibleFrame = _imagePlacement(
      style: style,
      projected: node,
      nodeScale: 1.5,
      assetPath: _usesWhite ? style.whiteExplorerImage : style.explorerImage,
    ).visibleFrame;
    const closeHitSize = 44.0;
    const closeSize = 34.0;
    final closeCenter = Offset(
      (visibleFrame.right - closeSize / 2 + 32).clamp(
        closeHitSize / 2,
        size.width - closeHitSize / 2,
      ),
      (visibleFrame.top - closeSize / 2 - 32).clamp(
        closeHitSize / 2,
        size.height - closeHitSize / 2,
      ),
    );
    final labelCenterY = math.min(size.height - 150, visibleFrame.bottom + 52);
    final labelWidth = math.min(size.width - 48, 360.0);

    return Stack(
      children: [
        Positioned(
          left: closeCenter.dx - closeHitSize / 2,
          top: closeCenter.dy - closeHitSize / 2,
          width: closeHitSize,
          height: closeHitSize,
          child: Semantics(
            label: '关闭当前风格',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(_clearSelection),
              child: Center(
                child: _ExplorerFocusCloseSurface(
                  child: const SizedBox(
                    width: closeSize,
                    height: closeSize,
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: (size.width - labelWidth) / 2,
          width: labelWidth,
          top: labelCenterY - 40,
          height: 80,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  style.title.replaceAll('\n', ' '),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '外观方案约 ¥${style.cost} 起',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControl() {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPadding = safeBottom + (_selectedItem == null ? 6 : 22);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          reverseDuration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .92, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: _buildBottomControlContent(),
        ),
      ),
    );
  }

  Widget _buildBottomControlContent() {
    if (_selectedItem != null) {
      return FilledButton(
        key: const ValueKey('open-style'),
        onPressed: () => widget.onOpenStyle(_styleIndexForItem(_selectedItem!)),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          backgroundColor: AppTheme.primary,
          shape: const StadiumBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '查看风格',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 13),
          ],
        ),
      );
    }

    final zoomedIn = _isZoomedIn;
    return Transform.scale(
      key: ValueKey(zoomedIn ? 'zoom-out' : 'overview-controls'),
      scale: .9,
      child: _ExplorerGlassSurface(
        radius: zoomedIn ? 20 : 28,
        child: SizedBox(
          width: zoomedIn ? 60 : 266,
          height: 56,
          child: zoomedIn
              ? Center(
                  child: _ExplorerControlButton(
                    semanticLabel: '返回风格全景',
                    width: 44,
                    icon: CupertinoIcons.minus,
                    iconSize: 20,
                    onTap: _showPanorama,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ExplorerControlButton(
                        semanticLabel: '放大风格画布',
                        width: 52,
                        icon: CupertinoIcons.plus,
                        iconSize: 23,
                        onTap: _zoomIn,
                      ),
                      Container(
                        width: 1.2,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        color: AppTheme.primary.withValues(alpha: .12),
                      ),
                      _colorButton('黑色', false),
                      _colorButton('白色', true),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _colorButton(String title, bool white) {
    final selected = _usesWhite == white;
    return Semantics(
      label: '切换为$title风格',
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_usesWhite == white) return;
          setState(() {
            _previousUsesWhite = _usesWhite;
            _usesWhite = white;
            _colorTransitioning = true;
          });
          _colorController.forward(from: 0);
          _wakeSceneTicker();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 96,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: .65) : null,
            borderRadius: BorderRadius.circular(23),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: .08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: selected ? AppTheme.primary : AppTheme.secondary,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  void _zoomIn() {
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _cameraZ = _focusCameraZ;
      _contentPosition = _clampedContentPosition(
        _contentPosition,
        size,
        _cameraZ,
      );
      _targetTiltX = 0;
      _targetTiltY = 0;
    });
    _wakeSceneTicker();
  }

  void _showPanorama() {
    setState(() {
      _clearSelection();
      _cameraZ = _overviewCameraZ;
      _contentPosition = _overviewCenter;
      _targetTiltX = 0;
      _targetTiltY = 0;
    });
    _wakeSceneTicker();
  }

  Widget _buildTuningPanel() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          width: 300,
          constraints: const BoxConstraints(maxHeight: 480),
          margin: const EdgeInsets.only(top: 62, right: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF12171C).withValues(alpha: .96),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                blurRadius: 36,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        '风格画布参数',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _resetTuning,
                        child: Text(
                          '重置',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .72),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: .12)),
                _tuningSection('网格', [
                  _tuningSlider('项目尺寸', _tileSize, 1.2, 2.2, (value) {
                    _updateTuning(() => _tileSize = value);
                  }, step: .05),
                  _tuningSlider('水平间距', _spacingX, 1.8, 3.2, (value) {
                    _updateTuning(() => _spacingX = value);
                  }, step: .05),
                  _tuningSlider('垂直间距', _spacingY, 1.8, 3.2, (value) {
                    _updateTuning(() => _spacingY = value);
                  }, step: .05),
                  _tuningSlider(
                    '全景距离',
                    _overviewCameraZ,
                    26,
                    48,
                    (value) {
                      _updateTuning(() {
                        if (_selectedItem == null && !_isZoomedIn) {
                          _cameraZ = value;
                        }
                        _overviewCameraZ = value;
                      });
                    },
                    step: 1,
                    digits: 0,
                  ),
                  _tuningSlider(
                    '视野角度',
                    _fieldOfView,
                    35,
                    60,
                    (value) {
                      _updateTuning(() => _fieldOfView = value);
                    },
                    step: 1,
                    digits: 0,
                  ),
                  _tuningSlider(
                    '曲率',
                    _curvature,
                    0,
                    .16,
                    (value) {
                      _updateTuning(() => _curvature = value);
                    },
                    step: .005,
                    digits: 3,
                  ),
                ]),
                Divider(height: 1, color: Colors.white.withValues(alpha: .12)),
                _tuningSection('交互', [
                  _tuningSlider('拖动速度', _dragSpeed, .8, 3.5, (value) {
                    _updateTuning(() => _dragSpeed = value);
                  }, step: .1),
                  _tuningSlider('位置阻尼', _positionDamping, .08, .5, (value) {
                    _updateTuning(() => _positionDamping = value);
                  }, step: .01),
                  _tuningSlider('镜头阻尼', _zoomDamping, .08, .6, (value) {
                    _updateTuning(() => _zoomDamping = value);
                  }, step: .01),
                  _tuningSlider('倾斜强度', _tiltStrength, 0, .2, (value) {
                    _updateTuning(() => _tiltStrength = value);
                  }, step: .01),
                  _tuningSlider('越界阻力', _dragResistance, .05, .8, (value) {
                    _updateTuning(() => _dragResistance = value);
                  }, step: .05),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tuningSection(String title, List<Widget> sliders) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...sliders,
        ],
      ),
    );
  }

  Widget _tuningSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    required double step,
    int digits = 2,
  }) {
    final divisions = ((max - min) / step).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                value.toStringAsFixed(digits),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .58),
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 20,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: .22),
                trackHeight: 2,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateTuning(VoidCallback update) {
    setState(update);
    _wakeSceneTicker();
  }

  void _resetTuning() {
    setState(() {
      _tileSize = 1.65;
      _spacingX = 2.45;
      _spacingY = 2.45;
      _overviewCameraZ = 34;
      _focusCameraZ = 12;
      _fieldOfView = 45;
      _curvature = .14;
      _dragSpeed = 2.2;
      _positionDamping = .2;
      _zoomDamping = .25;
      _tiltStrength = .08;
      _dragResistance = .25;
      if (_selectedItem != null || _isZoomedIn) {
        _cameraZ = _focusCameraZ;
      } else {
        _cameraZ = _overviewCameraZ;
        _contentPosition = _overviewCenter;
      }
      _targetTiltX = 0;
      _targetTiltY = 0;
    });
    _wakeSceneTicker();
  }
}

class _ExplorerCircleButton extends StatelessWidget {
  const _ExplorerCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 1.67),
      child: _ExplorerHeaderGlassSurface(
        child: _ExplorerControlButton(
          semanticLabel: semanticLabel,
          icon: icon,
          iconSize: icon == CupertinoIcons.slider_horizontal_3 ? 16 : 14,
          width: 60,
          height: 60,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _ExplorerControlButton extends StatelessWidget {
  const _ExplorerControlButton({
    required this.semanticLabel,
    required this.icon,
    required this.iconSize,
    required this.width,
    required this.onTap,
    this.height = 44,
  });

  final String semanticLabel;
  final IconData icon;
  final double iconSize;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: CustomPaint(
              size: Size.square(iconSize),
              painter: _ExplorerGlyphPainter(icon),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplorerGlyphPainter extends CustomPainter {
  const _ExplorerGlyphPainter(this.icon);

  final IconData icon;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = const Color(0xFF514347)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (icon == CupertinoIcons.slider_horizontal_3) {
      paint.strokeWidth = 1.6;
      final left = size.width * .09;
      final right = size.width * .91;
      final knobXs = [size.width * .64, size.width * .35, size.width * .70];
      final ys = [size.height * .2, size.height * .5, size.height * .8];
      final knobRadius = size.width * .095;
      for (var index = 0; index < ys.length; index++) {
        final y = ys[index];
        final knobX = knobXs[index];
        canvas.drawLine(Offset(left, y), Offset(knobX - knobRadius, y), paint);
        canvas.drawLine(Offset(knobX + knobRadius, y), Offset(right, y), paint);
        canvas.drawCircle(Offset(knobX, y), knobRadius, paint);
      }
      return;
    }

    if (icon == CupertinoIcons.xmark) {
      paint.strokeWidth = 2.0;
      final half = size.width * .34;
      final xmarkCenter = center + const Offset(.2, 0);
      canvas.drawLine(
        xmarkCenter - Offset(half, half),
        xmarkCenter + Offset(half, half),
        paint,
      );
      canvas.drawLine(
        xmarkCenter + Offset(half, -half),
        xmarkCenter + Offset(-half, half),
        paint,
      );
      return;
    }

    paint.strokeWidth = icon == CupertinoIcons.plus ? 3.5 : 3.7;
    final half = size.width * .34;
    final glyphCenter = Offset(center.dx + .5, center.dy);
    canvas.drawLine(
      Offset(glyphCenter.dx - half, glyphCenter.dy),
      Offset(glyphCenter.dx + half, glyphCenter.dy),
      paint,
    );
    if (icon == CupertinoIcons.plus) {
      canvas.drawLine(
        Offset(glyphCenter.dx, glyphCenter.dy - half),
        Offset(glyphCenter.dx, glyphCenter.dy + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ExplorerGlyphPainter oldDelegate) =>
      oldDelegate.icon != icon;
}

class _ExplorerGlassSurface extends StatelessWidget {
  const _ExplorerGlassSurface({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // SwiftUI's ultraThinMaterial settles around #F4F5F6 on this
              // white canvas. A light neutral tint keeps the glass readable
              // even when the animated topology happens to be on a blank
              // portion of its tile.
              color: const Color(0xFFF8F8F8).withValues(alpha: .88),
              borderRadius: shape,
              border: Border.all(color: Colors.white.withValues(alpha: .55)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ExplorerHeaderGlassSurface extends StatelessWidget {
  const _ExplorerHeaderGlassSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(28);
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          const BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ColoredBox(
            color: const Color(0xFFF8F8F8).withValues(alpha: .88),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ExplorerFocusCloseSurface extends StatelessWidget {
  const _ExplorerFocusCloseSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F5).withValues(alpha: .90),
            border: Border.all(color: AppTheme.primary.withValues(alpha: .55)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ExplorerLayoutNode {
  const _ExplorerLayoutNode({
    required this.itemIndex,
    required this.styleIndex,
    required this.projected,
    required this.depthOffset,
    required this.scale,
    required this.opacity,
    required this.selected,
  });

  final int itemIndex;
  final int styleIndex;
  final StyleExplorerProjectedNode projected;
  final double depthOffset;
  final double scale;
  final double opacity;
  final bool selected;
}

class _ExplorerImagePlacement {
  const _ExplorerImagePlacement({
    required this.imageRect,
    required this.visibleFrame,
    required this.fillCanvas,
  });

  final Rect imageRect;
  final Rect visibleFrame;
  final bool fillCanvas;
}

class _ExplorerCanvasGeometry {
  const _ExplorerCanvasGeometry({
    required this.canvasSize,
    required this.visibleBounds,
  });

  final Size canvasSize;
  final Rect visibleBounds;

  // The VK03-M Explorer asset contains a detached display label below the
  // chassis. Swift's SceneKit uses the catalog bounds for the chassis plane,
  // so the full cropped canvas must be positioned around that smaller bound.
  static const vk03Black = _ExplorerCanvasGeometry(
    canvasSize: Size(394, 513),
    visibleBounds: Rect.fromLTWH(
      .82111636,
      .6428096,
      392.68621638,
      404.3201024,
    ),
  );

  static const vk03White = _ExplorerCanvasGeometry(
    canvasSize: Size(503, 530),
    visibleBounds: Rect.fromLTWH(-.079744, 4.9744832, 485.869216, 381.7543872),
  );
}

class _TopologyBackground extends StatefulWidget {
  const _TopologyBackground({required this.controller, required this.opacity});

  final Animation<double> controller;
  final double opacity;

  @override
  State<_TopologyBackground> createState() => _TopologyBackgroundState();
}

class _TopologyBackgroundState extends State<_TopologyBackground> {
  static const _assetPath = 'assets/images/topology_contour_texture.png';
  ui.Image? _texture;

  @override
  void initState() {
    super.initState();
    _decodeTexture();
  }

  Future<void> _decodeTexture() async {
    try {
      final data = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _texture = frame.image);
    } catch (_) {
      // Keep the explorer usable if the optional texture cannot be decoded.
    }
  }

  @override
  void dispose() {
    _texture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.opacity,
        duration: const Duration(milliseconds: 300),
        child: ClipRect(
          child: CustomPaint(
            painter: _TopologyPainter(
              image: _texture,
              animation: widget.controller,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Draws the same explicit tile grid as Swift's `TopologyBackgroundUIView`.
///
/// The source PNG is a 2x (880x1640) asset, while Swift lays each tile out at
/// 440x820 logical points. Painting the tiles directly avoids an oversized
/// Flutter Stack being clipped to its parent's constraints.
class _TopologyPainter extends CustomPainter {
  _TopologyPainter({required this.image, required this.animation})
    : super(repaint: animation);

  static const _tileWidth = 440.0;
  static const _tileHeight = 820.0;

  final ui.Image? image;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final texture = image;
    if (texture == null || size.isEmpty) return;

    final columns = math.max(3, (size.width / _tileWidth).ceil() + 2);
    final rows = math.max(3, (size.height / _tileHeight).ceil() + 2);
    final progress = animation.value;
    final translation = Offset(
      -_tileWidth * progress,
      -_tileHeight + _tileHeight * progress,
    );
    final source = Rect.fromLTWH(
      0,
      0,
      texture.width.toDouble(),
      texture.height.toDouble(),
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final destination = Rect.fromLTWH(
          column * _tileWidth,
          row * _tileHeight,
          _tileWidth,
          _tileHeight,
        ).shift(translation);
        canvas.drawImageRect(texture, source, destination, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.animation != animation;
  }
}

class _ImmersiveButton extends StatelessWidget {
  const _ImmersiveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFDDE1E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.cube_box, size: 18),
                SizedBox(width: 7),
                Text(
                  '沉浸全景',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShowcaseRow extends StatelessWidget {
  const _ShowcaseRow({
    required this.index,
    required this.style,
    required this.onTap,
  });

  final int index;
  final _StyleShowcase style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: style.height,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 245,
              top: style.height - 22,
              child: Container(
                width: 156,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.025),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.065),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 172,
              top: style.imageYOffset,
              width: 297,
              height: 156,
              child: Transform.scale(
                scale: style.imageScale,
                child: Image.asset(style.image, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: Row(
                children: [
                  Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: const TextStyle(
                      color: Color(0xFFABB3BF),
                      fontSize: 16,
                      height: 1.31,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '/',
                    style: TextStyle(
                      color: Color(0xFFABB3BF),
                      fontSize: 18,
                      height: 1.17,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 42,
              width: 154,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.title,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Color(0xFF090D11),
                      fontSize: 16,
                      height: 1.19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '外观方案约',
                    style: TextStyle(
                      color: Color(0xFF808791),
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥ ${style.cost}',
                        style: const TextStyle(
                          color: Color(0xFF090D11),
                          fontSize: 14,
                          height: 1.29,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '起',
                        style: TextStyle(
                          color: Color(0xFF808791),
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  const CircleAvatar(
                    radius: 9.5,
                    backgroundColor: Color(0xFF090D11),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
