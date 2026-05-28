import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spark_joy_tokens.dart';

String sparkNormalizeExternalUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';
  if (!value.contains('://')) {
    value = 'https://$value';
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return '';
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return '';
  if (uri.host.trim().isEmpty) return '';
  return uri.toString();
}

class SparkExternalLinkRow extends StatelessWidget {
  const SparkExternalLinkRow({super.key, required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    final normalized = sparkNormalizeExternalUrl(url);
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Некорректная ссылка')));
      return;
    }
    final uri = Uri.parse(normalized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку')));
  }

  @override
  Widget build(BuildContext context) {
    final normalized = sparkNormalizeExternalUrl(url);
    final visibleUrl = normalized.isEmpty ? url.trim() : normalized;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(SparkRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SparkSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.open_in_new_rounded,
                  color: kSecondaryColor,
                  size: SparkSize.iconSm,
                ),
              ),
              const SizedBox(width: SparkSpace.sm),
              Expanded(
                child: MyText(
                  text: visibleUrl,
                  size: SparkTextSize.caption,
                  color: kSecondaryColor,
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
