// ignore_for_file: invalid_use_of_protected_member
part of 'painter_page.dart';

void clearAll(_PainterPageState state) {
  state.controller.clearDrawables();
  state.selectedDrawable = null;
  state.dragAction = DragAction.none;

  state.dragStart = null;
  state.previewShape = null;

  state.dragStartBounds = null;
  state.dragStartPointer = null;
  state.dragFixedCorner = null;
  state.startAngle = null;

  state._pressSnapTimer?.cancel();
  state._dragSnapAngle = null;
  state._isCreatingLineLike = false;
  state._firstAngleLockPending = false;

  state._laFixedEnd = null;
  state._laAngle = null;
  state._laDir = null;

  state._pressOnSelection = false;
  state._movedSinceDown = false;
  state._downScene = null;
  state._downHitDrawable = null;

  if (state.mounted) {
    state.setState(() {});
  }
}

Future<void> saveAsPng(_PainterPageState state, BuildContext context) async {
  final ui.Image image = await state.controller.renderImage(
    const Size(1200, 1200),
  );
  final bytes = await image.pngBytes;
  if (bytes == null) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Exported PNG Preview'),
      content: Image.memory(bytes),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> showPrintDialog(
  _PainterPageState state,
  BuildContext context,
) async {
  _LabelDocument? document;
  try {
    document = await _buildLabelDocument(state);
  } catch (e, stack) {
    debugPrint('build label document failed: $e\n$stack');
    if (state.mounted) {
      showSnackBar(context, '라벨 미리보기를 준비하지 못했습니다: $e', isError: true);
    }
    return;
  }

  final _LabelDocument doc = document;

  List<Printer> printers = <Printer>[];
  bool printerQueryFailed = false;
  try {
    printers = await Printing.listPrinters();
    printers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  } catch (e, stack) {
    printerQueryFailed = true;
    debugPrint('listPrinters failed: $e\n$stack');
  }

  Printer? preferredPrinter = _pickPreferredPrinter(printers);
  double? _knownDpiFor(Printer? printer) {
    // Prefer structured detection via PrinterProfile; fallback to legacy heuristics
    final profile = detectPrinterProfile(printer);
    if (profile.dpi != null) return profile.dpi;
    final String signature =
        ('${printer?.name ?? ''} ${printer?.location ?? ''} ${printer?.url ?? ''}')
            .toUpperCase();
    if (signature.contains('GODEX G500') || signature.contains('G500')) {
      return 203.0;
    }
    return null;
  }

  ({double width, double height})? _knownLabelFor(Printer? printer) {
    final profile = detectPrinterProfile(printer);
    if (profile.defaultWidthMm != null && profile.defaultHeightMm != null) {
      return (width: profile.defaultWidthMm!, height: profile.defaultHeightMm!);
    }
    final String signature =
        ('${printer?.name ?? ''} ${printer?.location ?? ''} ${printer?.url ?? ''}')
            .toUpperCase();
    if (signature.contains('GODEX G500') || signature.contains('G500')) {
      return (width: 80.0, height: 60.0);
    }
    return null;
  }

  Future<void> _updatePrinterProfile(Printer? printer) async {
    if (!state.mounted) return;
    double? dpiValue = _knownDpiFor(printer);
    if (dpiValue == null && Platform.isWindows && printer != null) {
      try {
        final int? rawDpi = await RawPrinterWin32.queryPrinterDpi(printer);
        if (rawDpi != null && rawDpi > 0) {
          dpiValue = rawDpi.toDouble();
        }
      } catch (e, stack) {
        debugPrint('query printer dpi failed: $e\n$stack');
      }
    }

    final profile = _knownLabelFor(printer);
    state.updateLabelSpec(
      dpi: dpiValue,
      widthMm: profile?.width,
      heightMm: profile?.height,
    );
  }

  if (preferredPrinter != null) {
    await _updatePrinterProfile(preferredPrinter);
  }
  if (!state.mounted) return;

  final bool isWindows = Platform.isWindows;
  final bool? printed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      Printer? selected = preferredPrinter;
      bool isPrinting = false;
      String? statusMessage;
      bool statusIsError = false;

      return StatefulBuilder(
        builder: (ctx, setStateDialog) {
          bool useVectorOverride = doc.rawIsVector;
          String sizeLabel = _formatPhysicalSize(doc.pixelSize, doc.dpi);
          return AlertDialog(
            title: const Text('라벨 출력'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: doc.pixelSize.width / doc.pixelSize.height,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.memory(
                            doc.previewBytes,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$sizeLabel · ${doc.dpi.toStringAsFixed(0)} DPI',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    Text(
                      doc.rawIsVector ? 'EZPL 벡터 명령 사용' : '래스터 이미지 출력',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: doc.rawIsVector ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('EZPL 벡터 명령으로 전송'),
                      subtitle: const Text('속도/선명도 우수. 문제가 있으면 해제하세요.'),
                      value: useVectorOverride,
                      onChanged: isPrinting
                          ? null
                          : (v) {
                              setStateDialog(() {
                                useVectorOverride = v;
                              });
                            },
                    ),
                    if (!isWindows) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Windows 이외의 환경에서는 직접 출력이 제한될 수 있습니다. 필요하면 "시스템 인쇄 대화상자"를 선택하세요.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('프린터 선택', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Printer?>(
                      value: selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<Printer?>(
                          value: null,
                          child: Text('시스템 인쇄 대화상자 사용'),
                        ),
                        ...printers.map(
                          (printer) => DropdownMenuItem<Printer?>(
                            value: printer,
                            child: Text(_printerDisplayName(printer)),
                          ),
                        ),
                      ],
                      onChanged: isPrinting
                          ? null
                          : (value) {
                              setStateDialog(() => selected = value);
                              if (value != null) {
                                _updatePrinterProfile(value);
                              }
                            },
                    ),
                    if (printers.isEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        printerQueryFailed
                            ? '프린터 목록을 불러오지 못했습니다. 시스템 인쇄 대화상자를 이용해 주세요.'
                            : '사용 가능한 프린터를 찾지 못했습니다. 시스템 인쇄 대화상자를 이용해 주세요.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                    if (statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        statusMessage!,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: statusIsError
                              ? Theme.of(ctx).colorScheme.error
                              : Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isPrinting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('닫기'),
              ),
              OutlinedButton(
                onPressed: isPrinting
                    ? null
                    : () => _showPreviewDialog(dialogContext, doc),
                child: const Text('미리보기'),
              ),
              FilledButton(
                onPressed: isPrinting
                    ? null
                    : () async {
                        setStateDialog(() {
                          isPrinting = true;
                          statusMessage = null;
                          statusIsError = false;
                        });

                        bool printed = false;
                        String? pendingMessage;
                        bool pendingIsError = false;
                        try {
                          if (selected != null) {
                            if (_canUseRawCommand(selected!)) {
                              try {
                                final Uint8List rawToSend = useVectorOverride
                                    ? doc.rawCommands
                                    : doc.fallbackRaster;
                                await RawPrinterWin32.sendRaw(
                                  selected!,
                                  rawToSend,
                                );
                                debugPrint('Raw print succeeded.');
                                printed = true;
                              } catch (e, stack) {
                                debugPrint('Raw print failed: $e\n$stack');
                                setStateDialog(() {
                                  statusMessage =
                                      '직접 명령 전송 실패: $e. PDF 출력으로 전환합니다.';
                                  statusIsError = true;
                                });
                              }
                            }

                            if (!printed) {
                              final bool direct = await Printing.directPrintPdf(
                                printer: selected!,
                                format: doc.pageFormat,
                                onLayout: (_) async => doc.pdfBytes,
                              );
                              if (direct) {
                                printed = true;
                              } else {
                                setStateDialog(() {
                                  statusMessage =
                                      '${_printerDisplayName(selected!)} 직접 출력이 실패했습니다. 시스템 인쇄 대화상자를 띄웁니다.';
                                  statusIsError = false;
                                });
                              }
                            }
                          }

                          if (!printed) {
                            final bool viaDialog = await Printing.layoutPdf(
                              format: doc.pageFormat,
                              name:
                                  'ITSnG_Label_${DateTime.now().millisecondsSinceEpoch}',
                              onLayout: (_) async => doc.pdfBytes,
                            );
                            if (viaDialog) {
                              printed = true;
                            } else {
                              pendingMessage = '인쇄가 취소되었습니다.';
                              pendingIsError = true;
                            }
                          }
                        } catch (e, stack) {
                          debugPrint('print failed: $e\n$stack');
                          pendingMessage = '인쇄 중 오류가 발생했습니다: $e';
                          pendingIsError = true;
                        }

                        if (printed) {
                          Navigator.of(dialogContext).pop(true);
                        } else {
                          setStateDialog(() {
                            isPrinting = false;
                            if (pendingMessage != null) {
                              statusMessage = pendingMessage;
                              statusIsError = pendingIsError;
                            }
                          });
                        }
                      },
                child: isPrinting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('프린트'),
              ),
            ],
          );
        },
      );
    },
  );

  if (printed == true && state.mounted) {
    showSnackBar(context, '인쇄 작업을 전송했습니다.');
  }
}

Future<void> pickImageAndAdd(_PainterPageState state) async {
  const typeGroup = XTypeGroup(
    label: 'images',
    extensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
  );
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return;

  final data = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(data));
  final frame = await codec.getNextFrame();
  final image = frame.image;

  const double maxSide = 320;
  double width = image.width.toDouble();
  double height = image.height.toDouble();
  final scale = (width > height) ? (maxSide / width) : (maxSide / height);
  if (scale < 1.0) {
    width *= scale;
    height *= scale;
  }

  final drawable = ImageBoxDrawable(
    position: const Offset(320, 320),
    image: image,
    size: Size(width, height),
    rotationAngle: 0,
    strokeWidth: 0,
  );

  state.controller.addDrawables([drawable]);
  state.setState(() {
    state.selectedDrawable = drawable;
    state.currentTool = tool.Tool.select;
    state.controller.freeStyleMode = FreeStyleMode.none;
    state.controller.scalingEnabled = true;
  });
}

Size _resolvePainterSize(_PainterPageState state) {
  final renderObject = state.controller.painterKey.currentContext
      ?.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    return renderObject.size;
  }

  final fallback = state._painterKey.currentContext?.findRenderObject();
  if (fallback is RenderBox && fallback.hasSize) {
    return fallback.size;
  }

  return const Size(640, 640);
}

Future<_LabelDocument> _buildLabelDocument(_PainterPageState state) async {
  final Size painterSize = _resolvePainterSize(state);
  if (painterSize.width <= 0 || painterSize.height <= 0) {
    throw StateError('캔버스 크기를 확인할 수 없습니다.');
  }

  final double dpi = state.printerDpi > 0 ? state.printerDpi : 300.0;
  final Size labelSize = state.labelPixelSize;
  if (labelSize.width <= 0 || labelSize.height <= 0) {
    throw StateError('라벨 크기를 확인할 수 없습니다.');
  }

  final ui.Image image = await state.controller.renderImage(labelSize);
  final ByteData? rawData = await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  final Uint8List? pngBytes = await image.pngBytes;
  if (rawData == null || pngBytes == null || pngBytes.isEmpty) {
    image.dispose();
    throw StateError('이미지를 생성하지 못했습니다.');
  }
  final Uint8List rgba = rawData.buffer.asUint8List();
  final int pixelWidth = image.width;
  final int pixelHeight = image.height;
  final int pixelCount = pixelWidth * pixelHeight;
  final Uint16List luminances = Uint16List(pixelCount);
  int luminanceSum = 0;
  for (int rgbaIndex = 0, p = 0; p < pixelCount; rgbaIndex += 4, p++) {
    final int r = rgba[rgbaIndex];
    final int g = rgba[rgbaIndex + 1];
    final int b = rgba[rgbaIndex + 2];
    final int luminance = ((r * 299) + (g * 587) + (b * 114)) ~/ 1000;
    luminances[p] = luminance;
    luminanceSum += luminance;
  }

  final int averageLum = luminanceSum ~/ pixelCount;
  final int adaptiveThreshold = math.max(
    90,
    math.min(210, averageLum + 20),
  ); // keep backgrounds light

  for (int rgbaIndex = 0, p = 0; p < pixelCount; rgbaIndex += 4, p++) {
    final int bw = luminances[p] <= adaptiveThreshold ? 0 : 255;
    rgba[rgbaIndex] = bw;
    rgba[rgbaIndex + 1] = bw;
    rgba[rgbaIndex + 2] = bw;
    rgba[rgbaIndex + 3] = 255;
  }
  image.dispose();

  final int bytesPerRow = ((pixelWidth + 7) ~/ 8);
  final Uint8List packed = Uint8List(bytesPerRow * pixelHeight);
  for (int y = 0; y < pixelHeight; y++) {
    final int rowBase = y * pixelWidth;
    for (int byteIndex = 0; byteIndex < bytesPerRow; byteIndex++) {
      int byteValue = 0;
      for (int bit = 0; bit < 8; bit++) {
        final int pixelX = byteIndex * 8 + bit;
        if (pixelX >= pixelWidth) {
          continue;
        }
        final int pixelIndex = rowBase + pixelX;
        final int rgbaIndex = pixelIndex * 4;
        final bool isDark = rgba[rgbaIndex] == 0;
        if (isDark) {
          byteValue |= (1 << (7 - bit));
        }
      }
      packed[y * bytesPerRow + byteIndex] = byteValue;
    }
  }

  final StringBuffer hexBuffer = StringBuffer();
  for (final int value in packed) {
    hexBuffer.write(value.toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  final int totalBytes = packed.length;
  final StringBuffer zpl = StringBuffer()
    ..write('^XA\r\n')
    ..write('^PW$pixelWidth\r\n')
    ..write('^LL$pixelHeight\r\n')
    ..write('^FO0,0\r\n')
    ..write(
      '^GFA,$totalBytes,$totalBytes,$bytesPerRow,${hexBuffer.toString()}\r\n',
    )
    ..write('^PQ1\r\n')
    ..write('^XZ\r\n');
  final Uint8List zplBytes = Uint8List.fromList(utf8.encode(zpl.toString()));

  final ezpl.EzplBuildResult ezplResult = ezpl.EzplBuilder(
    labelSizeDots: Size(pixelWidth.toDouble(), pixelHeight.toDouble()),
    sourceSize: labelSize,
    dpi: dpi,
  ).build(state.controller.value.drawables);
  final Uint8List vectorBytes = Uint8List.fromList(
    utf8.encode(ezplResult.commands),
  );
  final bool useVector = ezplResult.fullyVector;

  final double pageWidth = labelSize.width / dpi * PdfPageFormat.inch;
  final double pageHeight = labelSize.height / dpi * PdfPageFormat.inch;
  final PdfPageFormat pageFormat = PdfPageFormat(
    pageWidth,
    pageHeight,
    marginAll: 0,
  );

  final pw.Document doc = pw.Document();
  final pw.ImageProvider bwProvider = pw.RawImage(
    bytes: rgba,
    width: pixelWidth,
    height: pixelHeight,
    dpi: dpi,
  );

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (_) => pw.Container(
        width: pageWidth,
        height: pageHeight,
        alignment: pw.Alignment.center,
        child: pw.Image(
          bwProvider,
          width: pageWidth,
          height: pageHeight,
          dpi: dpi,
          fit: pw.BoxFit.fill,
        ),
      ),
    ),
  );

  final Uint8List pdfBytes = await doc.save();

  return _LabelDocument(
    previewBytes: pngBytes,
    pdfBytes: pdfBytes,
    pageFormat: pageFormat,
    pixelSize: Size(pixelWidth.toDouble(), pixelHeight.toDouble()),
    dpi: dpi,
    rawCommands: vectorBytes,
    fallbackRaster: zplBytes,
    rawIsVector: useVector,
  );
}

Future<void> _showPreviewDialog(BuildContext context, _LabelDocument document) {
  final double aspect = document.pixelSize.width / document.pixelSize.height;
  final double width = aspect >= 1 ? 640 : 480;
  final double rawHeight = width / aspect;
  double height = rawHeight;
  if (height < 320) height = 320;
  if (height > 720) height = 720;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('라벨 미리보기'),
      content: SizedBox(
        width: width,
        height: height,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8,
          child: Center(
            child: Image.memory(
              document.previewBytes,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

String _printerDisplayName(Printer printer) {
  final String name = printer.name.trim();
  final String location = (printer.location ?? '').trim();

  if (name.isNotEmpty) {
    if (location.isNotEmpty && location.toLowerCase() != name.toLowerCase()) {
      return '$name ($location)';
    }
    return name;
  }
  if (location.isNotEmpty) return location;
  final String url = printer.url.trim();
  if (url.isNotEmpty) return url;
  return '알 수 없는 프린터';
}

bool _canUseRawCommand(Printer printer) {
  if (!Platform.isWindows) return false;
  final profile = detectPrinterProfile(printer);
  return profile.canSendRaw && profile.language == PrinterLanguage.ezpl;
}

Printer? _pickPreferredPrinter(List<Printer> printers) {
  if (printers.isEmpty) return null;
  // Prefer EZPL-capable printers first (e.g., GoDEX). Otherwise, first in list.
  final ezplPrinters = printers.where(
    (p) => detectPrinterProfile(p).language == PrinterLanguage.ezpl,
  );
  if (ezplPrinters.isNotEmpty) return ezplPrinters.first;
  return printers.first;
}

String _formatPhysicalSize(Size pxSize, double dpi) {
  final double widthMm = pxSize.width / dpi * 25.4;
  final double heightMm = pxSize.height / dpi * 25.4;
  return '${widthMm.toStringAsFixed(1)} mm × ${heightMm.toStringAsFixed(1)} mm';
}

class _LabelDocument {
  final Uint8List previewBytes;
  final Uint8List pdfBytes;
  final PdfPageFormat pageFormat;
  final Size pixelSize;
  final double dpi;
  final Uint8List rawCommands; // EZPL vector commands
  final Uint8List fallbackRaster; // ZPL raster ^GFA
  final bool rawIsVector; // recommended default (true if fully vectorizable)

  const _LabelDocument({
    required this.previewBytes,
    required this.pdfBytes,
    required this.pageFormat,
    required this.pixelSize,
    required this.dpi,
    required this.rawCommands,
    required this.fallbackRaster,
    required this.rawIsVector,
  });
}
