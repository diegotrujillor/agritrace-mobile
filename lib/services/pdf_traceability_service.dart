import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/activity.dart';
import '../models/farm.dart';
import '../models/plot.dart';
import '../utils/constants.dart';
import '../utils/date_format.dart';

/// Timeout for the per-photo remote fetch. Short enough to keep the PDF
/// generation responsive when one photo is on a slow/dead URL; long enough
/// to survive a typical rural mobile connection.
const Duration kPdfPhotoFetchTimeout = Duration(seconds: 10);

/// Placeholder text rendered in the "Foto" cell when a remote photo could
/// not be retrieved (no network, timeout, 4xx/5xx). The PDF must still
/// generate — a single failed photo never blocks the document. Surfaced
/// to the producer so the missing thumbnail does not look like a bug.
const String kPdfPhotoUnavailableLabel = 'Foto no disponible (sin conexión)';

/// Client-side traceability PDF (W1c).
///
/// Builds a one-document trace of producer → finca → lote → activity
/// timeline and hands it to the platform share/print sheet via `printing`.
/// No Flutter widget deps — it is pure document generation so it can be
/// unit-tested by inspecting the returned bytes.
///
/// Photo resolution (v1.9.7): activities created on/after v0.6.0 of the
/// backend store `photoUrl` as a remote OCI Object Storage URL
/// (`https://objectstorage.sa-bogota-1.oraclecloud.com/…`), produced by
/// `POST /v1/uploads/photos`. Older activities still carry local
/// filesystem paths (optionally prefixed with `file://`). [_loadPhoto]
/// branches on the URL scheme so both shapes render. Remote fetches use
/// a dedicated [Dio] with NO API interceptors so the user's JWT is never
/// leaked to an unrelated host.
class PdfTraceabilityService {
  /// Default constructor uses a fresh, interceptor-free [Dio] with a 10 s
  /// total timeout. Inject [httpClient] in tests to stub the remote fetch.
  PdfTraceabilityService({Dio? httpClient})
      : _http = httpClient ?? _defaultHttpClient();

  final Dio _http;

  static Dio _defaultHttpClient() {
    // IMPORTANT: do NOT reuse the shared `ApiService` Dio here. That client
    // attaches the user's Bearer token to every outbound request, which
    // would leak the JWT to Oracle Object Storage on every photo fetch.
    return Dio(BaseOptions(
      connectTimeout: kPdfPhotoFetchTimeout,
      receiveTimeout: kPdfPhotoFetchTimeout,
      sendTimeout: kPdfPhotoFetchTimeout,
      responseType: ResponseType.bytes,
    ));
  }

  /// Builds the PDF document bytes.
  ///
  /// Photo bytes for activities with a non-null [Activity.photoUrl] are
  /// resolved before the synchronous document build begins. Local files
  /// that cannot be read and remote URLs that fail (network, timeout,
  /// non-2xx) are silently excluded from the [photos] map — the build
  /// continues and the corresponding row renders a "no photo" placeholder.
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
  /// Activities whose photo cannot be loaded are omitted from the returned
  /// map — the PDF row will render the [kPdfPhotoUnavailableLabel]
  /// placeholder instead of crashing.
  Future<Map<String, Uint8List>> _loadPhotos(
    List<Activity> activities,
  ) async {
    final result = <String, Uint8List>{};
    for (final activity in activities) {
      final url = activity.photoUrl;
      if (url == null || url.isEmpty) continue;
      final bytes = await _loadPhoto(url);
      if (bytes != null) {
        result[activity.id] = bytes;
      }
    }
    return result;
  }

  /// Resolves a single [pathOrUrl] to bytes.
  ///
  /// Branches on URL scheme:
  ///   - `http://` / `https://` → fetched via [_http] (no API interceptors,
  ///     so the user's JWT is NEVER attached to an OCI / external host).
  ///     Returns null on any [DioException] (network, timeout, non-2xx).
  ///   - `file://` and bare filesystem paths → read via [File].
  ///     Returns null when the file is missing or unreadable.
  ///
  /// `null` here means: "render the row with a placeholder, do not crash
  /// the rest of the PDF". This is intentional — a single missing photo
  /// must never block the whole report (offline-first requirement).
  Future<Uint8List?> _loadPhoto(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      try {
        final response = await _http.get<List<int>>(
          pathOrUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = response.data;
        if (data == null || data.isEmpty) {
          developer.log(
            'PDF photo fetch returned empty body for $pathOrUrl',
            name: 'PdfTraceabilityService',
          );
          return null;
        }
        return Uint8List.fromList(data);
      } on DioException catch (e) {
        developer.log(
          'PDF photo fetch failed for $pathOrUrl: ${e.type} ${e.message}',
          name: 'PdfTraceabilityService',
        );
        return null;
      }
    }
    final path = pathOrUrl.startsWith('file://')
        ? pathOrUrl.replaceFirst('file://', '')
        : pathOrUrl;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } on IOException {
      // File missing or unreadable — skip thumbnail for this activity.
      return null;
    }
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
          // v1.9.2 — QA cycle-02: human label for the plot enum value so
          // the PDF reads "Caña panelera" instead of "cana_panelera".
          _row('Cultivo (lote)', cropTypeLabel(plot.cropType)),
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

    // v1.9.7 — when bytes are present we render the thumbnail; when the
    // activity carries a photoUrl that we could NOT resolve, surface the
    // placeholder so the producer knows the data exists but is offline;
    // otherwise leave the cell empty (activity simply had no photo).
    final hasPhotoUrl =
        activity.photoUrl != null && activity.photoUrl!.isNotEmpty;
    final photoCell = pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: photoBytes != null
          ? pw.Image(
              pw.MemoryImage(photoBytes),
              width: 80,
              height: 80,
              fit: pw.BoxFit.cover,
            )
          : (hasPhotoUrl
              ? pw.Text(
                  kPdfPhotoUnavailableLabel,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                )
              : pw.SizedBox()),
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
