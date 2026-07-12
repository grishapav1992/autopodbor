import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spark_joy_tokens.dart';

enum SparkJoyAttachmentOpenMode { media, pdf, external }

SparkJoyAttachmentOpenMode sparkJoyAttachmentOpenMode({
  required String mimeType,
  required String displayName,
}) {
  final mime = mimeType.trim().toLowerCase();
  if (mime.startsWith('image/') || mime.startsWith('video/')) {
    return SparkJoyAttachmentOpenMode.media;
  }
  if (mime == 'application/pdf' ||
      displayName.trim().toLowerCase().endsWith('.pdf')) {
    return SparkJoyAttachmentOpenMode.pdf;
  }
  return SparkJoyAttachmentOpenMode.external;
}

/// In-app PDF viewer for both local draft files and presigned report URLs.
class SparkJoyPdfViewerScreen extends StatelessWidget {
  const SparkJoyPdfViewerScreen({
    super.key,
    required this.source,
    required this.title,
  });

  final String source;
  final String title;

  @override
  Widget build(BuildContext context) {
    final localPath = sparkJoyLocalDocumentPath(source);
    final params = PdfViewerParams(
      loadingBannerBuilder: (context, downloaded, total) => Center(
        child: CircularProgressIndicator(
          value: total == null || total <= 0 ? null : downloaded / total,
        ),
      ),
      errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SparkSpace.section),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: SparkSpace.md),
              const Text('Не удалось открыть PDF', textAlign: TextAlign.center),
              const SizedBox(height: SparkSpace.sm),
              OutlinedButton(
                onPressed: () => openSparkJoyExternalDocument(
                  context,
                  source: source,
                  mimeType: 'application/pdf',
                ),
                child: const Text('Открыть в другом приложении'),
              ),
            ],
          ),
        ),
      ),
    );
    final viewer = localPath != null
        ? PdfViewer.file(localPath, params: params)
        : PdfViewer.uri(Uri.parse(source), params: params);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: viewer,
    );
  }
}

String? sparkJoyLocalDocumentPath(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.scheme == 'file') {
    try {
      return uri.toFilePath();
    } catch (_) {
      return null;
    }
  }
  if (uri == null || uri.scheme.isEmpty) return trimmed;
  return null;
}

/// Opens office and other non-previewable documents in a compatible system
/// application. Remote completed-report files are opened by their presigned
/// URL; local draft files go through the native document interaction API.
Future<void> openSparkJoyExternalDocument(
  BuildContext context, {
  required String source,
  required String mimeType,
}) async {
  final localPath = sparkJoyLocalDocumentPath(source);
  if (!kIsWeb && localPath != null) {
    final result = await OpenFilex.open(localPath, type: mimeType);
    if (result.type == ResultType.done) return;
  } else {
    final uri = Uri.tryParse(source.trim());
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('На устройстве нет приложения для открытия этого файла'),
    ),
  );
}
