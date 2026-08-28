// ignore_for_file: implementation_imports

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:ui' as _i1;
import 'package:flutter/src/widget_previews/widget_previews.dart' as _i2;
import 'widget_preview.dart' as _i3;
import 'utils.dart' as _i4;
import 'package:insoulv1/home_screen.dart' as _i5;
import 'package:insoulv1/main.dart' as _i6;

List<_i3.WidgetPreview> previews() => [
  _i4.buildWidgetPreview(
    packageName: 'insoulv1',
    scriptUri: 'file:///D:/insoulv1_stitch_ui/insoulv1/lib/home_screen.dart',
    line: 26,
    column: 1,
    previewFunction: () => _i5.homeScreenPreview(),
    transformedPreview:
        _i2.Preview(
          name: 'InSoul home screen',
          size: _i1.Size(480.0, 900.0),
        ).transform(),
  ),
  _i4.buildWidgetPreview(
    packageName: 'insoulv1',
    scriptUri: 'file:///D:/insoulv1_stitch_ui/insoulv1/lib/main.dart',
    line: 51,
    column: 1,
    previewFunction: () => _i6.inSoulHomePreview(),
    transformedPreview:
        _i2.Preview(
          name: 'InSoul home screen',
          size: _i1.Size(480.0, 900.0),
        ).transform(),
  ),
];
