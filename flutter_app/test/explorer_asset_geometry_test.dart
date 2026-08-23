import 'package:flutter_test/flutter_test.dart';
import 'package:uzbox_flutter/explorer_asset_geometry.dart';

void main() {
  test('reports the generated Explorer asset aspect ratios', () {
    expect(
      ExplorerAssetGeometry.aspectRatio(
        'assets/images/explorer/style_vision_compact_black.webp',
      ),
      closeTo(407 / 462, 1e-12),
    );
    expect(
      ExplorerAssetGeometry.aspectRatio(
        'assets/images/explorer/style_catalog_StyleASUSTUF502AmmoBlack.webp',
      ),
      1,
    );
  });
}
