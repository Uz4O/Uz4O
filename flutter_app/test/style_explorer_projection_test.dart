import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:uzbox_flutter/style_explorer_projection.dart';

void main() {
  test('projects a central panorama node with the Swift defaults', () {
    const projection = StyleExplorerProjection(Size(440, 956));

    final node = projection.project(20);

    expect(node.center.dx, closeTo(178.92, 0.01));
    expect(node.center.dy, closeTo(437.76, 0.01));
    expect(node.pointsPerWorld, closeTo(33.53, 0.01));
    expect(node.visibleMaxSide(), closeTo(48.69, 0.01));
  });

  test('matches the default 440 by 956 panorama center bounds', () {
    const projection = StyleExplorerProjection(Size(440, 956));
    final nodes = List.generate(
      StyleExplorerProjection.itemCount,
      projection.project,
    );

    final xs = nodes.map((node) => node.center.dx);
    final ys = nodes.map((node) => node.center.dy);

    expect(xs.reduce(mathMin), closeTo(40.85, 0.01));
    expect(xs.reduce(mathMax), closeTo(399.15, 0.01));
    expect(ys.reduce(mathMin), closeTo(256.00, 0.01));
    expect(ys.reduce(mathMax), closeTo(657.65, 0.01));
  });

  test('perspective makes the central node larger than a far corner', () {
    const projection = StyleExplorerProjection(Size(440, 956));

    final cornerSide = projection.project(0).visibleMaxSide();
    final centralSide = projection.project(20).visibleMaxSide();

    expect(cornerSide, closeTo(33.86, 0.01));
    expect(centralSide, closeTo(48.69, 0.01));
    expect(centralSide / cornerSide, closeTo(1.438, 0.001));
  });

  test('defines 42 unique positions in the six by seven world grid', () {
    final positions = List.generate(
      StyleExplorerProjection.itemCount,
      StyleExplorerProjection.worldPosition,
    );

    expect(positions.toSet(), hasLength(42));
    expect(positions.map((position) => position.dx).toSet(), hasLength(6));
    expect(positions.map((position) => position.dy).toSet(), hasLength(7));
    expect(positions.first.dx, closeTo(-6.125, 1e-12));
    expect(positions.first.dy, closeTo(7.35, 1e-12));
    expect(positions.last.dx, closeTo(6.125, 1e-12));
    expect(positions.last.dy, closeTo(-7.35, 1e-12));
  });

  test('keeps the vertical-FOV projection responsive at 600 by 960', () {
    const projection = StyleExplorerProjection(Size(600, 960));
    final nodes = List.generate(
      StyleExplorerProjection.itemCount,
      projection.project,
    );
    final xs = nodes.map((node) => node.center.dx);
    final ys = nodes.map((node) => node.center.dy);

    expect(xs.reduce(mathMin), closeTo(120.10, 0.01));
    expect(xs.reduce(mathMax), closeTo(479.90, 0.01));
    expect(ys.reduce(mathMin), closeTo(257.07, 0.01));
    expect(ys.reduce(mathMax), closeTo(660.40, 0.01));
    expect(projection.project(20).visibleMaxSide(), closeTo(48.90, 0.01));
  });

  test('smoothsteps curvature between focus and panorama camera distances', () {
    const focus = StyleExplorerProjection(Size(440, 956), cameraZ: 12);
    const halfway = StyleExplorerProjection(Size(440, 956), cameraZ: 23);
    const panorama = StyleExplorerProjection(Size(440, 956));

    expect(focus.curveBlend, 0);
    expect(focus.project(0).depth, 0);
    expect(halfway.curveBlend, closeTo(.5, 1e-12));
    expect(halfway.project(0).depth, closeTo(-7.74326875, 1e-8));
    expect(halfway.project(0).distance, closeTo(30.74326875, 1e-8));
    expect(panorama.curveBlend, 1);
  });

  test('projects SceneKit focus depth and tuning spacing', () {
    const projection = StyleExplorerProjection(
      Size(440, 956),
      cameraZ: 12,
      contentPositionWorld: Offset(6, -7),
      gridSpacingX: 2.4,
      gridSpacingY: 7 / 3,
    );

    final selected = projection.project(0, depthOffset: 2);

    expect(selected.worldPosition, Offset.zero);
    expect(selected.depth, 2);
    expect(selected.distance, 10);
    expect(selected.center, const Offset(220, 478));
  });

  test('moves color-transition clones without recomputing curvature', () {
    const projection = StyleExplorerProjection(Size(440, 956));

    final base = projection.project(0, depthOffset: -18);
    final shifted = projection.project(
      0,
      depthOffset: -18,
      worldOffset: const Offset(0, 0.75),
    );

    expect(shifted.depth, base.depth);
    expect(shifted.pointsPerWorld, base.pointsPerWorld);
    expect(shifted.center.dx, base.center.dx);
    expect(
      shifted.center.dy,
      closeTo(base.center.dy - .75 * base.pointsPerWorld, 1e-10),
    );
  });
}

double mathMin(double left, double right) => left < right ? left : right;

double mathMax(double left, double right) => left > right ? left : right;
