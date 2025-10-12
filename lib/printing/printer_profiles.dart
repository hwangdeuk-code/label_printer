import 'dart:io';
import 'package:printing/printing.dart';

/// Logical printer language families we may support.
enum PrinterLanguage {
  ezpl, // Godex EZPL-compatible
  zpl,  // Zebra ZPL (future)
  tspl, // TSC TSPL (future)
  cpcl, // CPCL (future)
  rasterOnly,
}

class PrinterProfile {
  final String vendor;
  final String model;
  final PrinterLanguage language;
  final double? dpi; // known default DPI if available
  final double? defaultWidthMm;
  final double? defaultHeightMm;

  const PrinterProfile({
    required this.vendor,
    required this.model,
    required this.language,
    this.dpi,
    this.defaultWidthMm,
    this.defaultHeightMm,
  });

  bool get canSendRaw => Platform.isWindows && language != PrinterLanguage.rasterOnly;

  @override
  String toString() =>
      'PrinterProfile(vendor=$vendor, model=$model, lang=$language, dpi=$dpi, ${defaultWidthMm}x${defaultHeightMm}mm)';
}

/// Best-effort detection based on the available fields in [Printer].
/// This is string-matching and can be extended in the future for new models.
PrinterProfile detectPrinterProfile(Printer? printer) {
  final String name = (printer?.name ?? '').toUpperCase();
  final String location = (printer?.location ?? '').toUpperCase();
  final String url = (printer?.url ?? '').toUpperCase();
  final String signature = '$name $location $url';

  // Godex G500 (and generally Godex): EZPL, 203dpi typical, 80x60mm default
  if (signature.contains('GODEX G500') || signature.contains('G500')) {
    return const PrinterProfile(
      vendor: 'GoDEX',
      model: 'G500',
      language: PrinterLanguage.ezpl,
      dpi: 203,
      defaultWidthMm: 80.0,
      defaultHeightMm: 60.0,
    );
  }
  if (signature.contains('GODEX') || signature.contains('EZPL')) {
    return const PrinterProfile(
      vendor: 'GoDEX',
      model: 'Unknown',
      language: PrinterLanguage.ezpl,
      dpi: 203,
    );
  }

  // Placeholder heuristics for future support
  if (signature.contains('ZEBRA') || signature.contains('ZPL')) {
    return const PrinterProfile(
      vendor: 'Zebra',
      model: 'Unknown',
      language: PrinterLanguage.zpl,
    );
  }
  if (signature.contains('TSC') || signature.contains('TSPL')) {
    return const PrinterProfile(
      vendor: 'TSC',
      model: 'Unknown',
      language: PrinterLanguage.tspl,
    );
  }

  return const PrinterProfile(
    vendor: 'Unknown',
    model: 'Unknown',
    language: PrinterLanguage.rasterOnly,
  );
}
