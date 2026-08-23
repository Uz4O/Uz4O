import 'dart:math' as math;
import 'dart:ui';

/// Projects the style explorer's 6×7 world grid using the Swift SceneKit
/// camera model.
final class StyleExplorerProjection {
  const StyleExplorerProjection(
    this.viewport, {
    this.cameraZ = 34,
    this.contentPositionWorld = const Offset(0, 1.2),
    this.fieldOfViewDegrees = 45,
    this.curvatureStrength = .14,
    this.minimumZoom = 12,
    this.maximumZoom = 34,
    this.gridSpacingX = spacingX,
    this.gridSpacingY = spacingY,
  }) : assert(fieldOfViewDegrees > 0 && fieldOfViewDegrees < 180),
       assert(minimumZoom < maximumZoom);

  static const int columns = 6;
  static const int rows = 7;
  static const int itemCount = columns * rows;
  static const double spacingX = 2.45;
  static const double spacingY = 2.45;

  final Size viewport;
  final double cameraZ;
  final Offset contentPositionWorld;
  final double fieldOfViewDegrees;
  final double curvatureStrength;
  final double minimumZoom;
  final double maximumZoom;
  final double gridSpacingX;
  final double gridSpacingY;

  static Offset worldPosition(int itemIndex) {
    if (itemIndex < 0 || itemIndex >= itemCount) {
      throw RangeError.range(itemIndex, 0, itemCount - 1, 'itemIndex');
    }

    final column = itemIndex % columns;
    final row = itemIndex ~/ columns;
    return Offset(
      (column - (columns - 1) / 2) * spacingX,
      ((rows - 1) / 2 - row) * spacingY,
    );
  }

  StyleExplorerProjectedNode project(
    int itemIndex, {
    double depthOffset = 0,
    Offset worldOffset = Offset.zero,
  }) {
    if (itemIndex < 0 || itemIndex >= itemCount) {
      throw RangeError.range(itemIndex, 0, itemCount - 1, 'itemIndex');
    }
    final column = itemIndex % columns;
    final row = itemIndex ~/ columns;
    final gridPosition = Offset(
      (column - (columns - 1) / 2) * gridSpacingX,
      ((rows - 1) / 2 - row) * gridSpacingY,
    );
    final baseVisiblePosition = gridPosition + contentPositionWorld;
    final visiblePosition = baseVisiblePosition + worldOffset;
    final curvedDepth =
        -(baseVisiblePosition.dx * baseVisiblePosition.dx +
            baseVisiblePosition.dy * baseVisiblePosition.dy) *
        curvatureStrength *
        curveBlend;
    final depth = curvedDepth + depthOffset;
    final distance = cameraZ - depth;
    final pointsPerWorld = _focalLength / distance;

    return StyleExplorerProjectedNode(
      itemIndex: itemIndex,
      gridPosition: gridPosition,
      worldPosition: visiblePosition,
      center: Offset(
        viewport.width / 2 + visiblePosition.dx * pointsPerWorld,
        viewport.height / 2 - visiblePosition.dy * pointsPerWorld,
      ),
      pointsPerWorld: pointsPerWorld,
      depth: depth,
      distance: distance,
    );
  }

  double get curveBlend {
    final progress = ((cameraZ - minimumZoom) / (maximumZoom - minimumZoom))
        .clamp(0.0, 1.0);
    return progress * progress * (3 - 2 * progress);
  }

  double get _focalLength =>
      viewport.height / (2 * math.tan(fieldOfViewDegrees * math.pi / 360));
}

final class StyleExplorerProjectedNode {
  const StyleExplorerProjectedNode({
    required this.itemIndex,
    required this.gridPosition,
    required this.worldPosition,
    required this.center,
    required this.pointsPerWorld,
    required this.depth,
    required this.distance,
  });

  final int itemIndex;
  final Offset gridPosition;
  final Offset worldPosition;
  final Offset center;
  final double pointsPerWorld;
  final double depth;
  final double distance;

  double visibleMaxSide({double tileSize = 1.65}) =>
      tileSize * .88 * pointsPerWorld;
}
