import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_document_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes media, PDF and office documents to the right viewer', () {
    expect(
      sparkJoyAttachmentOpenMode(
        mimeType: 'image/jpeg',
        displayName: 'STS.jpg',
      ),
      SparkJoyAttachmentOpenMode.media,
    );
    expect(
      sparkJoyAttachmentOpenMode(
        mimeType: 'application/octet-stream',
        displayName: 'report.PDF',
      ),
      SparkJoyAttachmentOpenMode.pdf,
    );
    expect(
      sparkJoyAttachmentOpenMode(
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        displayName: 'report.docx',
      ),
      SparkJoyAttachmentOpenMode.external,
    );
  });

  test('extracts a local path without treating https as a file', () {
    expect(
      sparkJoyLocalDocumentPath('file:///tmp/report%20one.pdf'),
      '/tmp/report one.pdf',
    );
    expect(sparkJoyLocalDocumentPath('https://example.com/report.pdf'), isNull);
  });
}
