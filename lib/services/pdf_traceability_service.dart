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
/// `Farm` has no producer field in the model, so [producerName] is supplied
/// by the caller from auth state (nullable → shown as "—").
class PdfTraceabilityService {
  const PdfTraceabilityService();

  /// Builds the PDF document bytes. Pure — no side effects.
  Future<Uint8List> build({
    required Farm farm,
    required Plot plot,
    required List<Activity> activities,
    String? producerName,
  }) async {
    final sorted = [...activities]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _header(),
          pw.SizedBox(height: 16),
          _summary(
            producerName: producerName,
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
            _activityTable(sorted),
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
  }) async {
    final bytes = await build(
      farm: farm,
      plot: plot,
      activities: activities,
      producerName: producerName,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'trazabilidad_${plot.name}.pdf',
    );
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
    required Farm farm,
    required Plot plot,
  }) {
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
          _row('Finca', farm.name),
          _row('Cultivo (finca)', farm.cropType),
          _row('Lote', plot.name),
          _row('Cultivo (lote)', plot.cropType),
          if (plot.variety != null && plot.variety!.isNotEmpty)
            _row('Variedad', plot.variety!),
          _row('Estado', plot.status.label),
        ],
      ),
    );
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

  pw.Widget _activityTable(List<Activity> activities) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Fecha', 'Tipo', 'Nota'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FixedColumnWidth(70),
        1: pw.FixedColumnWidth(110),
        2: pw.FlexColumnWidth(),
      },
      data: [
        for (final a in activities)
          [
            formatLocalDate(a.occurredAt),
            a.type.label,
            (a.description == null || a.description!.isEmpty)
                ? '—'
                : a.description!,
          ],
      ],
    );
  }
}
