import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.report});

  final Map<String, dynamic> report;

  Color _verdictColor(String verdict) {
    if (verdict == 'Можно покупать') {
      return kGreenColor;
    }
    if (verdict == 'Нужна проверка') {
      return kYellowColor;
    }
    return kRedColor;
  }

  @override
  Widget build(BuildContext context) {
    final verdict = report['verdict'] ?? '';
    final images = (report['images'] as List<dynamic>?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчет'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: AppSizes.DEFAULT,
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loading) {
                        if (loading == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: kBorderColor,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 16),
          MyText(
            text: report['car'] ?? 'Автомобиль',
            size: 18,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 6),
          MyText(
            text: 'Эксперт: ${report['inspector'] ?? '-'}',
            size: 12,
            color: kGreyColor,
          ),
          const SizedBox(height: 6),
          MyText(
            text: 'Дата отчета: ${report['date'] ?? '-'}',
            size: 12,
            color: kGreyColor,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _verdictColor(verdict).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _verdictColor(verdict).withValues(alpha: 0.4),
              ),
            ),
            child: MyText(
              text: verdict,
              size: 12,
              weight: FontWeight.w700,
              color: _verdictColor(verdict),
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(title: 'Оценка', value: report['score'] ?? '-'),
          _InfoRow(title: 'Рыночная цена', value: report['price'] ?? '-'),
          _InfoRow(
            title: 'Отчетов по авто',
            value: '${report['reportsCount'] ?? 1}',
          ),
          const SizedBox(height: 10),
          MyText(
            text: 'Замечания',
            size: 14,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 6),
          MyText(
            text: report['issues'] ?? '-',
            size: 12,
            color: kGreyColor,
            lineHeight: 1.4,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: MyText(
              text: title,
              size: 12,
              color: kGreyColor,
            ),
          ),
          MyText(
            text: value,
            size: 12,
            weight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}
