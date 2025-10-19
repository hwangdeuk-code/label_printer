import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:printing/printing.dart';
import 'package:win32/win32.dart';

class RawPrinterWin32 {
  const RawPrinterWin32._();

  static Future<void> sendRaw(Printer printer, Uint8List data) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Raw printing is only supported on Windows.');
    }
    // printing.Printer.name is non-nullable; avoid dead null-aware checks
    final String printerName = printer.name;
    if (printerName.isEmpty) {
      throw ArgumentError('Printer name is not available.');
    }
    if (data.isEmpty) {
      throw StateError('Empty printer command payload.');
    }

    final Pointer<HANDLE> phPrinter = calloc<HANDLE>();
    final Pointer<Utf16> namePtr = printerName.toNativeUtf16();
    try {
      final int openResult = OpenPrinter(namePtr, phPrinter, nullptr);
      if (openResult == 0) {
        throw StateError('OpenPrinter failed with error ${GetLastError()}');
      }

      final Pointer<DOC_INFO_1> docInfo = calloc<DOC_INFO_1>();
      final Pointer<Utf16> docName = 'Label Job'.toNativeUtf16();
      final Pointer<Utf16> dataType = 'RAW'.toNativeUtf16();
      docInfo.ref
        ..pDocName = docName
        ..pOutputFile = nullptr
        ..pDatatype = dataType;

      try {
        final int startDoc = StartDocPrinter(phPrinter.value, 1, docInfo);
        if (startDoc == 0) {
          throw StateError('StartDocPrinter failed (${GetLastError()})');
        }
        try {
          if (StartPagePrinter(phPrinter.value) == 0) {
            throw StateError('StartPagePrinter failed (${GetLastError()})');
          }

          final Pointer<Uint8> dataPtr = calloc<Uint8>(data.length);
          final Uint8List dataList = dataPtr.asTypedList(data.length);
          dataList.setAll(0, data);
          final Pointer<DWORD> written = calloc<DWORD>();
          try {
            final int writeResult = WritePrinter(
              phPrinter.value,
              dataPtr.cast(),
              data.length,
              written,
            );
            if (writeResult == 0 || written.value != data.length) {
              throw StateError('WritePrinter failed (${GetLastError()})');
            }
          } finally {
            calloc.free(written);
            calloc.free(dataPtr);
          }

          if (EndPagePrinter(phPrinter.value) == 0) {
            throw StateError('EndPagePrinter failed (${GetLastError()})');
          }
        } finally {
          EndDocPrinter(phPrinter.value);
        }
      } finally {
        calloc.free(docInfo);
        calloc.free(docName);
        calloc.free(dataType);
      }
    } finally {
      ClosePrinter(phPrinter.value);
      calloc.free(phPrinter);
      calloc.free(namePtr);
    }
  }

  static Future<int?> queryPrinterDpi(Printer printer) async {
    if (!Platform.isWindows) return null;
    final String printerName = printer.name;
    if (printerName.isEmpty) {
      return null;
    }

    final Pointer<Utf16> driverPtr = 'WINSPOOL'.toNativeUtf16();
    final Pointer<Utf16> devicePtr = printerName.toNativeUtf16();
    try {
      final int hdc = CreateDC(driverPtr, devicePtr, nullptr, nullptr);
      if (hdc == 0) {
        return null;
      }
      try {
        final int dpiX = GetDeviceCaps(hdc, LOGPIXELSX);
        final int dpiY = GetDeviceCaps(hdc, LOGPIXELSY);
        int? dpi;
        if (dpiX > 0 && dpiY > 0) {
          dpi = ((dpiX + dpiY) / 2).round();
        } else if (dpiX > 0) {
          dpi = dpiX;
        } else if (dpiY > 0) {
          dpi = dpiY;
        }
        return dpi;
      } finally {
        DeleteDC(hdc);
      }
    } finally {
      calloc.free(driverPtr);
      calloc.free(devicePtr);
    }
  }
}
