import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

/// Renders a photo served by the AgriTrace backend's authenticated
/// endpoint (`GET /v1/uploads/photos/:id`).
///
/// Why this exists: the OCI bucket `agritrace-uploads` is private since
/// backend v0.7.0, so `Image.network` cannot fetch the bytes anonymously
/// — and Flutter's default `Image.network` does not run the Dio
/// `_AuthInterceptor` either. We fetch the bytes through the shared
/// `apiServiceProvider` Dio (which attaches the Bearer token, refreshes
/// on 401 once, and surfaces session-collapsed sentinels) and render
/// `Image.memory` with the result.
///
/// The widget is intentionally minimal: it shows a small progress
/// indicator while bytes are in-flight and a `broken_image` icon on any
/// load failure. Callers that want richer error UX should layer their
/// own state on top.
class AuthenticatedNetworkImage extends ConsumerStatefulWidget {
  const AuthenticatedNetworkImage({
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    super.key,
  });

  /// Full URL to fetch (typically `<API_BASE>/uploads/photos/<id>`).
  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  ConsumerState<AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState
    extends ConsumerState<AuthenticatedNetworkImage> {
  Future<Uint8List>? _future;
  String? _resolvedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedFor != widget.url) {
      _resolvedFor = widget.url;
      _future = _load(widget.url);
    }
  }

  @override
  void didUpdateWidget(covariant AuthenticatedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolvedFor = widget.url;
      _future = _load(widget.url);
    }
  }

  Future<Uint8List> _load(String url) async {
    final api = ref.read(apiServiceProvider);
    final response = await api.client.getUri<List<int>>(
      Uri.parse(url),
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const FormatException('Empty image body');
    }
    return Uint8List.fromList(data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Static placeholder during fetch — no animation. A spinning
          // indicator would prevent `pumpAndSettle` from terminating in
          // widget tests that render an existing photo URL, even with
          // mocked Dio.
          return Container(
            height: widget.height,
            width: widget.width,
            color: AppColors.lightGrey,
            child: const Center(
              child: Icon(Icons.image_outlined),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            height: widget.height,
            width: widget.width,
            color: AppColors.lightGrey,
            child: const Center(
              child: Icon(Icons.broken_image_outlined),
            ),
          );
        }
        return Image.memory(
          snapshot.data!,
          height: widget.height,
          width: widget.width,
          fit: widget.fit,
        );
      },
    );
  }
}
