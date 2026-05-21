import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/activity.dart';
import '../models/farm.dart';
import '../models/plot.dart';
import '../utils/date_format.dart';

/// Client-side traceability PDF (W1c).
///
/// Builds a one-document trace of producer → finca → lote → activity
/// timeline and hands it to the platform share/print sheet via `printing`.
/// No Flutter widget deps and no network — it is pure document generation so
/// it can be unit-tested by inspecting the returned bytes.
///
/// Producer contact fields ([producerPhone], [producerEmail]) and the
/// producer name are supplied by the caller from auth state (nullable →
/// omitted when empty/null).
class PdfTraceabilityService {
  const PdfTraceabilityService();

  /// Builds the PDF document bytes.
  ///
  /// Photo bytes for activities with a local [Activity.photoUrl] are
  /// resolved before the synchronous document build begins. Missing or
  /// unreadable files are silently skipped — they never crash the PDF.
  Future<Uint8List> build({
    required Farm farm,
    required Plot plot,
    required List<Activity> activities,
    String? producerName,
    String? producerPhone,
    String? producerEmail,
  }) async {
    final sorted = [...activities]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final photos = await _loadPhotos(sorted);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _header(),
          pw.SizedBox(height: 16),
          _summary(
            producerName: producerName,
            producerPhone: producerPhone,
            producerEmail: producerEmail,
            farm: farm,
            plot: plot,
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Línea de tiempo de actividades',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (sorted.isEmpty)
            pw.Text('Sin actividades registradas.')
          else
            _activityList(sorted, photos),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ),
      ),
    );
    return doc.save();
  }

  /// Builds the document and opens the platform share/print sheet.
  Future<void> buildAndShare({
    required Farm farm,
    required Plot plot,
    required List<Activity> activities,
    String? producerName,
    String? producerPhone,
    String? producerEmail,
  }) async {
    final bytes = await build(
      farm: farm,
      plot: plot,
      activities: activities,
      producerName: producerName,
      producerPhone: producerPhone,
      producerEmail: producerEmail,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'trazabilidad_${plot.name}.pdf',
    );
  }

  /// Loads photo bytes for every activity that has a non-null [photoUrl].
  ///
  /// `file://` prefixes are stripped before the path is passed to [File].
  /// Any I/O error (file not found, permission denied) is caught and that
  /// activity is excluded from the returned map — the PDF build continues
  /// without that thumbnail.
  Future<Map<String, Uint8List>> _loadPhotos(
    List<Activity> activities,
  ) async {
    final result = <String, Uint8List>{};
    for (final activity in activities) {
      final url = activity.photoUrl;
      if (url == null || url.isEmpty) continue;
      final path =
          url.startsWith('file://') ? url.replaceFirst('file://', '') : url;
      try {
        result[activity.id] = await File(path).readAsBytes();
      } on IOException {
        // File missing or unreadable — skip thumbnail for this activity.
      }
    }
    return result;
  }

  pw.Widget _header() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'AgriTrace',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor.fromInt(0xFF1B5028),
          ),
        ),
        pw.Text(
          'Reporte de trazabilidad',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _summary({
    required String? producerName,
    required String? producerPhone,
    required String? producerEmail,
    required Farm farm,
    required Plot plot,
  }) {
    final gps = _farmGpsLabel(farm.latitude, farm.longitude);
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFE8F5E9),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _row('Productor', producerName ?? '—'),
          if (producerPhone != null && producerPhone.isNotEmpty)
            _row('Teléfono', producerPhone),
          if (producerEmail != null && producerEmail.isNotEmpty)
            _row('Email', producerEmail),
          _row('Finca', farm.name),
          _row('Cultivo (finca)', farm.cropType),
          if (gps != null) _row('GPS (finca)', gps),
          _row('Lote', plot.name),
          _row('Cultivo (lote)', plot.cropType),
          if (plot.variety != null && plot.variety!.isNotEmpty)
            _row('Variedad', plot.variety!),
          _row('Estado', plot.status.label),
        ],
      ),
    );
  }

  /// Returns formatted GPS string when both coordinates are non-null,
  /// e.g. `"10.3932° N, 75.4832° W"`. Returns null when either is absent.
  String? _farmGpsLabel(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    final latAbs = latitude.abs().toStringAsFixed(4);
    final lngAbs = longitude.abs().toStringAsFixed(4);
    final latDir = latitude >= 0 ? 'N' : 'S';
    final lngDir = longitude >= 0 ? 'E' : 'W';
    return '$latAbs° $latDir, $lngAbs° $lngDir';
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _activityList(
    List<Activity> activities,
    Map<String, Uint8List> photos,
  ) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(65),
        1: pw.FixedColumnWidth(100),
        2: pw.FlexColumnWidth(),
        3: pw.FixedColumnWidth(88),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        _activityHeaderRow(),
        for (final a in activities) _activityDataRow(a, photos[a.id]),
      ],
    );
  }

  pw.TableRow _activityHeaderRow() {
    pw.Widget cell(String text) => pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        );
    return pw.TableRow(
      children: [cell('Fecha'), cell('Tipo'), cell('Nota'), cell('Foto')],
    );
  }

  pw.TableRow _activityDataRow(Activity activity, Uint8List? photoBytes) {
    pw.Widget textCell(String text) => pw.Container(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
        );

    final photoCell = pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: photoBytes != null
          ? pw.Image(
              pw.MemoryImage(photoBytes),
              width: 80,
              height: 80,
              fit: pw.BoxFit.cover,
            )
          : pw.SizedBox(),
    );

    final note =
        (activity.description == null || activity.description!.isEmpty)
            ? '—'
            : activity.description!;

    return pw.TableRow(
      children: [
        textCell(formatLocalDate(activity.occurredAt)),
        textCell(activity.type.label),
        textCell(note),
        photoCell,
      ],
    );
  }
}
