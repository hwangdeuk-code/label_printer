import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/barcode.dart' show BarcodeType;
import 'package:flutter/material.dart';

import '../drawables/barcode_drawable.dart';
import '../drawables/constrained_text_drawable.dart';
import '../drawables/image_box_drawable.dart';
import '../drawables/table_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/drawable.dart';
import '../flutter_painter_v2/controllers/drawables/image_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/object_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/path/erase_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/path/free_style_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/arrow_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/double_arrow_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/line_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/oval_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/shape/rectangle_drawable.dart';
import '../flutter_painter_v2/controllers/drawables/text_drawable.dart';
import '../models/tool.dart' show TxtAlign;

class DrawableSerializationResult {
  DrawableSerializationResult({required this.drawable, required this.id});

  final Drawable drawable;
  final String id;
}

class DrawableSerializer {
  static const _version = 2;

  static Map<String, dynamic> wrapScene({
    required double printerDpi,
    required double labelWidthMm,
    required double labelHeightMm,
    required List<Map<String, dynamic>> objects,
  }) {
    return {
      'version': _version,
      'generatedAt': DateTime.now().toIso8601String(),
      'printerDpi': printerDpi,
      'labelWidthMm': labelWidthMm,
      'labelHeightMm': labelHeightMm,
      'objects': objects,
    };
  }

  static Future<Map<String, dynamic>> toJson(
    Drawable drawable,
    String id,
  ) async {
    final type = _detectType(drawable);
    final base = <String, dynamic>{'id': id, 'type': type};

    if (drawable is ObjectDrawable) {
      base.addAll({
        'position': _offsetToJson(drawable.position),
        'rotation': drawable.rotationAngle,
        'scale': drawable.scale,
        'locked': drawable.locked,
        'hidden': drawable.hidden,
      });
    } else {
      base['hidden'] = drawable.hidden;
    }

    switch (drawable) {
      case RectangleDrawable rect:
        base.addAll({
          'size': _sizeToJson(rect.size),
          'paint': _paintToJson(rect.paint),
          'borderRadius': _borderRadiusToJson(rect.borderRadius),
        });
      case OvalDrawable oval:
        base.addAll({
          'size': _sizeToJson(oval.size),
          'paint': _paintToJson(oval.paint),
        });
      case LineDrawable line:
        base.addAll({'length': line.length, 'paint': _paintToJson(line.paint)});
      case ArrowDrawable arrow:
        base.addAll({
          'length': arrow.length,
          'paint': _paintToJson(arrow.paint),
          'arrowHeadSize': arrow.arrowHeadSize,
        });
      case DoubleArrowDrawable arrow:
        base.addAll({
          'length': arrow.length,
          'paint': _paintToJson(arrow.paint),
        });
      case FreeStyleDrawable stroke:
        base.addAll({
          'path': stroke.path.map(_offsetToJson).toList(),
          'strokeWidth': stroke.strokeWidth,
          'color': stroke.color.toARGB32(),
        });
      case EraseDrawable eraser:
        base.addAll({
          'path': eraser.path.map(_offsetToJson).toList(),
          'strokeWidth': eraser.strokeWidth,
        });
      case ConstrainedTextDrawable text:
        base.addAll({
          'text': text.text,
          'style': _textStyleToJson(text.style),
          'direction': text.direction.name,
          'align': text.align.name,
          'maxWidth': text.maxWidth,
        });
      case TextDrawable plainText:
        base.addAll({
          'text': plainText.text,
          'style': _textStyleToJson(plainText.style),
          'direction': plainText.direction.name,
        });
      case BarcodeDrawable barcode:
        base.addAll({
          'data': barcode.data,
          'barcodeType': barcode.type.name,
          'showValue': barcode.showValue,
          'fontSize': barcode.fontSize,
          'foreground': barcode.foreground.toARGB32(),
          'background': barcode.background.toARGB32(),
          'bold': barcode.bold,
          'italic': barcode.italic,
          'fontFamily': barcode.fontFamily,
          'textAlign': barcode.textAlign?.name,
          'maxTextWidth': barcode.maxTextWidth,
          'microModule': barcode.microModule,
          'strictValidation': barcode.strictValidation,
          'humanReadableGrouped': barcode.humanReadableGrouped,
          'size': _sizeToJson(barcode.size),
        });
      case ImageBoxDrawable image:
        base.addAll({
          'size': _sizeToJson(image.size),
          'borderRadius': _borderRadiusToJson(image.borderRadius),
          'strokeColor': image.strokeColor.toARGB32(),
          'strokeWidth': image.strokeWidth,
          'image': await _encodeImage(image.image),
        });
      case ImageDrawable image:
        base.addAll({'image': await _encodeImage(image.image)});
      case TableDrawable table:
        base.addAll({
          'rows': table.rows,
          'columns': table.columns,
          'size': _sizeToJson(table.size),
          'rowFractions': table.rowFractions,
          'columnFractions': table.columnFractions,
          'cellStyles': table.cellStyles,
          'cellDeltaJson': table.cellDeltaJson,
          // 내부 분할 및 내부 서브셀 데이터 직렬화(선택적)
          'internalColFractions': table.internalColFractions,
          'internalCellDeltaJson': table.internalCellDeltaJson,
          'internalCellStyles': table.internalCellStyles,
          'internalCellPaddings': table.internalCellPaddings.map(
            (key, list) => MapEntry(
              key,
              list
                  .map(
                    (p) => p == null
                        ? null
                        : {
                            'top': p.top,
                            'right': p.right,
                            'bottom': p.bottom,
                            'left': p.left,
                          },
                  )
                  .toList(),
            ),
          ),
          'mergedSpans': table.mergedSpans.map(
            (key, span) => MapEntry(key, {
              'rowSpan': span.rowSpan,
              'colSpan': span.colSpan,
            }),
          ),
          'mergedParents': table.mergedParents,
          'cellBorders': table.cellBorders.map(
            (key, value) => MapEntry(key, {
              'top': value.top,
              'right': value.right,
              'bottom': value.bottom,
              'left': value.left,
            }),
          ),
          'cellBorderStyles': table.cellBorderStyles.map(
            (key, value) => MapEntry(key, {
              'top': value.top.name,
              'right': value.right.name,
              'bottom': value.bottom.name,
              'left': value.left.name,
            }),
          ),
          'cellPaddings': table.cellPaddings.map(
            (key, value) => MapEntry(key, {
              'top': value.top,
              'right': value.right,
              'bottom': value.bottom,
              'left': value.left,
            }),
          ),
        });
      default:
        // Fallback: store runtime type
        base['runtimeType'] = drawable.runtimeType.toString();
    }

    return base;
  }

  static Future<DrawableSerializationResult?> fromJson(
    Map<String, dynamic> json,
  ) async {
    final id = json['id'];
    final type = json['type'];
    if (id is! String || type is! String) return null;

    Drawable? drawable;
    try {
      switch (type) {
        case 'rectangle':
          drawable = RectangleDrawable(
            size: _jsonToSize(json['size']),
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            paint: _jsonToPaint(json['paint']),
            borderRadius: _jsonToBorderRadius(json['borderRadius']),
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'oval':
          drawable = OvalDrawable(
            size: _jsonToSize(json['size']),
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            paint: _jsonToPaint(json['paint']),
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'line':
          drawable = LineDrawable(
            length: (json['length'] as num).toDouble(),
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            paint: _jsonToPaint(json['paint']),
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'arrow':
          drawable = ArrowDrawable(
            length: (json['length'] as num).toDouble(),
            arrowHeadSize: (json['arrowHeadSize'] as num?)?.toDouble(),
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            paint: _jsonToPaint(json['paint']),
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'double-arrow':
          drawable = DoubleArrowDrawable(
            length: (json['length'] as num).toDouble(),
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            paint: _jsonToPaint(json['paint']),
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'stroke':
          drawable = FreeStyleDrawable(
            path: _jsonToPath(json['path']),
            strokeWidth: (json['strokeWidth'] as num).toDouble(),
            color: Color(json['color'] as int),
            hidden: json['hidden'] == true,
          );
        case 'eraser':
          drawable = EraseDrawable(
            path: _jsonToPath(json['path']),
            strokeWidth: (json['strokeWidth'] as num).toDouble(),
            hidden: json['hidden'] == true,
          );
        case 'text-block':
          drawable = ConstrainedTextDrawable(
            text: json['text'] as String? ?? '',
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            style: _jsonToTextStyle(json['style']),
            direction: _jsonToTextDirection(json['direction']),
            align: _jsonToTxtAlign(json['align']),
            maxWidth: (json['maxWidth'] as num?)?.toDouble() ?? 300,
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'text':
          drawable = TextDrawable(
            text: json['text'] as String? ?? '',
            position: _jsonToOffset(json['position']),
            rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            style: _jsonToTextStyle(json['style']),
            direction: _jsonToTextDirection(json['direction']),
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'barcode':
          drawable = BarcodeDrawable(
            data: json['data'] as String? ?? '',
            type: _jsonToBarcodeType(json['barcodeType'] ?? json['type']),
            showValue: json['showValue'] == true,
            fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
            foreground: Color(
              json['foreground'] as int? ?? Colors.black.toARGB32(),
            ),
            background: Color(
              json['background'] as int? ?? Colors.white.toARGB32(),
            ),
            bold: json['bold'] == true,
            italic: json['italic'] == true,
            fontFamily: json['fontFamily'] as String? ?? 'Roboto',
            textAlign: _jsonToTextAlign(json['textAlign']),
            maxTextWidth: (json['maxTextWidth'] as num?)?.toDouble() ?? 0,
            microModule: (json['microModule'] as num?)?.toInt(),
            strictValidation: json['strictValidation'] == true,
            humanReadableGrouped: json['humanReadableGrouped'] == true,
            size: _jsonToSize(json['size']),
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'image-box':
          final bytes = base64Decode(json['image'] as String);
          final image = await _decodeImage(bytes);
          drawable = ImageBoxDrawable(
            image: image,
            size: _jsonToSize(json['size']),
            borderRadius: _jsonToBorderRadius(json['borderRadius']),
            strokeColor: Color(
              json['strokeColor'] as int? ?? Colors.black.toARGB32(),
            ),
            strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 0,
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'image':
          final bytes = base64Decode(json['image'] as String);
          final image = await _decodeImage(bytes);
          drawable = ImageDrawable(
            image: image,
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
          );
        case 'table':
          final rows = json['rows'] as int;
          final columns = json['columns'] as int;
          // fractions가 누락되었거나 길이가 맞지 않는 이전 저장본 대비 안전 처리
          final List<double> rawColFracs =
              (json['columnFractions'] as List<dynamic>?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              const <double>[];
          final List<double> rawRowFracs =
              (json['rowFractions'] as List<dynamic>?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              const <double>[];
          final columnFractions = _coerceFractions(rawColFracs, columns);
          final rowFractions = _coerceFractions(rawRowFracs, rows);
          final table = TableDrawable(
            rows: rows,
            columns: columns,
            columnFractions: columnFractions,
            rowFractions: rowFractions,
            size: _jsonToSize(json['size']),
            position: _jsonToOffset(json['position']),
            rotationAngle: (json['rotation'] as num?)?.toDouble() ?? 0,
            scale: (json['scale'] as num?)?.toDouble() ?? 1,
            hidden: json['hidden'] == true,
            locked: json['locked'] == true,
            cellBorders: _jsonToBorders(json['cellBorders']),
            cellBorderStyles: _jsonToBorderStyles(json['cellBorderStyles']),
            cellPaddings: _jsonToPaddings(json['cellPaddings']),
          );
          table.cellStyles.addAll(
            (json['cellStyles'] as Map).map(
              (key, value) => MapEntry(
                key as String,
                Map<String, dynamic>.from(value as Map),
              ),
            ),
          );
          table.cellDeltaJson.addAll(
            (json['cellDeltaJson'] as Map).map(
              (key, value) => MapEntry(key as String, value as String),
            ),
          );
          table.mergedSpans.addAll(
            (json['mergedSpans'] as Map).map((key, value) {
              final map = value as Map;
              return MapEntry(
                key as String,
                CellMergeSpan(
                  rowSpan: map['rowSpan'] as int,
                  colSpan: map['colSpan'] as int,
                ),
              );
            }),
          );
          table.mergedParents.addAll(
            (json['mergedParents'] as Map).map(
              (key, value) => MapEntry(key as String, value as String),
            ),
          );
          // Sanity: drop parents pointing to non-existent roots
          table.mergedParents.removeWhere(
            (child, parent) => !table.mergedSpans.containsKey(parent),
          );

          // 내부 분할/서브셀 데이터 복원(있을 때만)
          final icf = json['internalColFractions'];
          if (icf is Map) {
            icf.forEach((key, value) {
              final list = (value as List?)
                  ?.map((e) => (e as num).toDouble())
                  .toList();
              if (list != null)
                table.internalColFractions[key as String] = list;
            });
          }
          final iDelta = json['internalCellDeltaJson'];
          if (iDelta is Map) {
            iDelta.forEach((key, value) {
              final list = (value as List?)?.map((e) => e as String?).toList();
              if (list != null)
                table.internalCellDeltaJson[key as String] = list;
            });
          }
          final iStyles = json['internalCellStyles'];
          if (iStyles is Map) {
            iStyles.forEach((key, value) {
              final list =
                  (value as List?)
                      ?.map(
                        (e) => e == null
                            ? null
                            : Map<String, dynamic>.from(e as Map),
                      )
                      .toList() ??
                  const <Map<String, dynamic>?>[];
              table.internalCellStyles[key as String] = list;
            });
          }
          final iPads = json['internalCellPaddings'];
          if (iPads is Map) {
            iPads.forEach((key, value) {
              final list =
                  (value as List?)
                      ?.map(
                        (e) => e == null
                            ? null
                            : CellPadding(
                                top: (e['top'] as num?)?.toDouble() ?? 0,
                                right: (e['right'] as num?)?.toDouble() ?? 0,
                                bottom: (e['bottom'] as num?)?.toDouble() ?? 0,
                                left: (e['left'] as num?)?.toDouble() ?? 0,
                              ),
                      )
                      .toList() ??
                  const <CellPadding?>[];
              table.internalCellPaddings[key as String] = list;
            });
          }
          drawable = table;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }

    return DrawableSerializationResult(drawable: drawable, id: id);
  }

  static String _detectType(Drawable drawable) {
    if (drawable is RectangleDrawable) return 'rectangle';
    if (drawable is OvalDrawable) return 'oval';
    if (drawable is LineDrawable) return 'line';
    if (drawable is ArrowDrawable) return 'arrow';
    if (drawable is DoubleArrowDrawable) return 'double-arrow';
    if (drawable is FreeStyleDrawable) return 'stroke';
    if (drawable is EraseDrawable) return 'eraser';
    if (drawable is ConstrainedTextDrawable) return 'text-block';
    if (drawable is TextDrawable) return 'text';
    if (drawable is BarcodeDrawable) return 'barcode';
    if (drawable is ImageBoxDrawable) return 'image-box';
    if (drawable is ImageDrawable) return 'image';
    if (drawable is TableDrawable) return 'table';
    return drawable.runtimeType.toString();
  }

  static Map<String, double> _offsetToJson(Offset offset) => {
    'x': offset.dx,
    'y': offset.dy,
  };

  static Offset _jsonToOffset(dynamic value) {
    if (value is Map) {
      final x = (value['x'] as num?)?.toDouble() ?? 0;
      final y = (value['y'] as num?)?.toDouble() ?? 0;
      return Offset(x, y);
    }
    throw const FormatException('Invalid offset');
  }

  static Map<String, double> _sizeToJson(Size size) => {
    'width': size.width,
    'height': size.height,
  };

  static Size _jsonToSize(dynamic value) {
    if (value is Map) {
      final width = (value['width'] as num?)?.toDouble() ?? 0;
      final height = (value['height'] as num?)?.toDouble() ?? 0;
      return Size(width, height);
    }
    throw const FormatException('Invalid size');
  }

  static Map<String, dynamic> _paintToJson(Paint paint) {
    return {
      'color': paint.color.toARGB32(),
      'strokeWidth': paint.strokeWidth,
      'style': paint.style.name,
      'strokeCap': paint.strokeCap.name,
      'strokeJoin': paint.strokeJoin.name,
    };
  }

  static Paint _jsonToPaint(dynamic value) {
    if (value is! Map) throw const FormatException('Invalid paint');
    final paint = Paint()
      ..color = Color(value['color'] as int? ?? Colors.black.toARGB32())
      ..strokeWidth = (value['strokeWidth'] as num?)?.toDouble() ?? 1
      ..style = PaintingStyle.values.firstWhere(
        (e) => e.name == value['style'],
        orElse: () => PaintingStyle.stroke,
      )
      ..strokeCap = StrokeCap.values.firstWhere(
        (e) => e.name == value['strokeCap'],
        orElse: () => StrokeCap.round,
      )
      ..strokeJoin = StrokeJoin.values.firstWhere(
        (e) => e.name == value['strokeJoin'],
        orElse: () => StrokeJoin.round,
      );
    return paint;
  }

  static Map<String, dynamic> _borderRadiusToJson(BorderRadius radius) {
    return {
      'topLeft': _radiusToJson(radius.topLeft),
      'topRight': _radiusToJson(radius.topRight),
      'bottomLeft': _radiusToJson(radius.bottomLeft),
      'bottomRight': _radiusToJson(radius.bottomRight),
    };
  }

  static BorderRadius _jsonToBorderRadius(dynamic value) {
    if (value is! Map) {
      return const BorderRadius.all(Radius.zero);
    }
    return BorderRadius.only(
      topLeft: _jsonToRadius(value['topLeft']),
      topRight: _jsonToRadius(value['topRight']),
      bottomLeft: _jsonToRadius(value['bottomLeft']),
      bottomRight: _jsonToRadius(value['bottomRight']),
    );
  }

  static Map<String, double> _radiusToJson(Radius radius) => {
    'x': radius.x,
    'y': radius.y,
  };

  static Radius _jsonToRadius(dynamic value) {
    if (value is! Map) return Radius.zero;
    final x = (value['x'] as num?)?.toDouble() ?? 0;
    final y = (value['y'] as num?)?.toDouble() ?? 0;
    return Radius.elliptical(x, y);
  }

  static Map<String, dynamic> _textStyleToJson(TextStyle style) {
    return {
      'color': style.color?.toARGB32(),
      'fontSize': style.fontSize,
      'fontWeight': style.fontWeight?.index,
      'fontStyle': style.fontStyle?.index,
      'fontFamily': style.fontFamily,
    };
  }

  static TextStyle _jsonToTextStyle(dynamic value) {
    if (value is! Map)
      return const TextStyle(fontSize: 14, color: Colors.black);
    return TextStyle(
      color: value['color'] != null ? Color(value['color'] as int) : null,
      fontSize: (value['fontSize'] as num?)?.toDouble(),
      fontWeight: value['fontWeight'] != null
          ? FontWeight.values[value['fontWeight'] as int]
          : null,
      fontStyle: value['fontStyle'] != null
          ? FontStyle.values[value['fontStyle'] as int]
          : null,
      fontFamily: value['fontFamily'] as String?,
    );
  }

  static TextDirection _jsonToTextDirection(dynamic value) {
    if (value is String) {
      return TextDirection.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TextDirection.ltr,
      );
    }
    return TextDirection.ltr;
  }

  static TxtAlign _jsonToTxtAlign(dynamic value) {
    if (value is String) {
      return TxtAlign.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TxtAlign.left,
      );
    }
    return TxtAlign.left;
  }

  static TextAlign? _jsonToTextAlign(dynamic value) {
    if (value is String) {
      return TextAlign.values.firstWhere(
        (e) => e.name == value,
        orElse: () => TextAlign.center,
      );
    }
    return null;
  }

  static BarcodeType _jsonToBarcodeType(dynamic value) {
    if (value is String) {
      return BarcodeType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => BarcodeType.Code128,
      );
    }
    return BarcodeType.Code128;
  }

  static List<Offset> _jsonToPath(dynamic value) {
    if (value is! List) throw const FormatException('Invalid path');
    return value.map((e) => _jsonToOffset(e)).toList();
  }

  static Future<String> _encodeImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw const FormatException('Failed to encode image');
    }
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    return base64Encode(bytes);
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Map<String, CellBorderThickness> _jsonToBorders(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, dynamic v) {
      final map = v as Map;
      return MapEntry(
        key as String,
        CellBorderThickness(
          top: (map['top'] as num?)?.toDouble() ?? 1,
          right: (map['right'] as num?)?.toDouble() ?? 1,
          bottom: (map['bottom'] as num?)?.toDouble() ?? 1,
          left: (map['left'] as num?)?.toDouble() ?? 1,
        ),
      );
    });
  }

  static Map<String, CellPadding> _jsonToPaddings(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, dynamic v) {
      final map = v as Map;
      return MapEntry(
        key as String,
        CellPadding(
          top: (map['top'] as num?)?.toDouble() ?? 0,
          right: (map['right'] as num?)?.toDouble() ?? 0,
          bottom: (map['bottom'] as num?)?.toDouble() ?? 0,
          left: (map['left'] as num?)?.toDouble() ?? 0,
        ),
      );
    });
  }

  static Map<String, CellBorderStyles> _jsonToBorderStyles(dynamic value) {
    if (value is! Map) return {};
    CellBorderStyle _styleOf(dynamic name) {
      if (name is String) {
        return CellBorderStyle.values.firstWhere(
          (e) => e.name == name,
          orElse: () => CellBorderStyle.solid,
        );
      }
      return CellBorderStyle.solid;
    }

    return value.map((key, dynamic v) {
      final map = v as Map;
      return MapEntry(
        key as String,
        CellBorderStyles(
          top: _styleOf(map['top']),
          right: _styleOf(map['right']),
          bottom: _styleOf(map['bottom']),
          left: _styleOf(map['left']),
        ),
      );
    });
  }

  // rows/columns 수에 맞춰 fractions를 보정한다.
  // - 길이가 다르면 자르거나(pad) 균등 분배해 맞춘 후 합이 1.0이 되도록 정규화.
  static List<double> _coerceFractions(List<double> source, int count) {
    if (count <= 0) return const <double>[];
    if (source.isEmpty) {
      return List<double>.filled(count, 1.0 / count);
    }
    List<double> list;
    if (source.length == count) {
      list = List<double>.from(source);
    } else if (source.length > count) {
      list = List<double>.from(source.take(count));
    } else {
      // pad with equal remainder
      list = List<double>.from(source);
      final int deficit = count - source.length;
      final double pad = 1.0 / count; // temporary pad, will renormalize below
      list.addAll(List<double>.filled(deficit, pad));
    }
    // normalize to sum 1.0 (avoid zeros/negatives)
    double sum = 0.0;
    for (final v in list) {
      if (v.isFinite && v > 0) sum += v;
    }
    if (sum <= 0) {
      return List<double>.filled(count, 1.0 / count);
    }
    return list.map((v) => (v.isFinite && v > 0) ? (v / sum) : 0.0).toList();
  }
}
