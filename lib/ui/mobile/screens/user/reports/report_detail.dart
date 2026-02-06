import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'dart:ui';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _purchased = false;

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
    final report = widget.report;
    final verdict = report['verdict'] ?? '';
    final images = (report['images'] as List<dynamic>?)?.cast<String>() ?? [];
    final premium = (report['premium'] as Map<String, dynamic>?) ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчет'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: AppSizes.listPaddingWithBottomBar(),
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
          const SizedBox(height: 12),
          const _SectionTitle(text: 'Общие данные'),
          _InfoRow(title: 'VIN', value: report['vin'] ?? '-'),
          _InfoRow(title: 'Пробег', value: report['mileage'] ?? '-'),
          _InfoRow(title: 'Владельцы', value: report['owners'] ?? '-'),
          _InfoRow(title: 'Двигатель', value: report['engine'] ?? '-'),
          _InfoRow(title: 'КПП', value: report['transmission'] ?? '-'),
          _InfoRow(title: 'Привод', value: report['drive'] ?? '-'),
          const SizedBox(height: 10),
          const _SectionTitle(text: 'Краткое резюме'),
          MyText(
            text: report['summary'] ?? '-',
            size: 12,
            color: kGreyColor,
            lineHeight: 1.4,
          ),
          const SizedBox(height: 12),
          const _SectionTitle(text: 'Замечания'),
          MyText(
            text: report['issues'] ?? '-',
            size: 12,
            color: kGreyColor,
            lineHeight: 1.4,
          ),
          const SizedBox(height: 16),
          const _SectionTitle(text: 'Платная часть отчета'),
          const SizedBox(height: 6),
          _LockedInfoCard(
            title: 'Толщина ЛКП и окрасы',
            content: premium['paintThickness'] ?? 'Нет данных',
            locked: !_purchased,
          ),
          const SizedBox(height: 10),
          _LockedInfoCard(
            title: 'Фото по элементам',
            content: premium['panelPhotos'] ?? 'Нет данных',
            locked: !_purchased,
          ),
          const SizedBox(height: 10),
          _LockedInfoCard(
            title: 'Видео осмотра',
            content: premium['video'] ?? 'Нет данных',
            locked: !_purchased,
          ),
          const SizedBox(height: 10),
          _LockedInfoCard(
            title: 'Юридическая проверка',
            content: premium['legal'] ?? 'Нет данных',
            locked: !_purchased,
          ),
          const SizedBox(height: 16),
          if (!_purchased)
            ElevatedButton(
              onPressed: () {
                setState(() => _purchased = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Отчет куплен')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kSecondaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Купить отчет',
                style: TextStyle(color: kWhiteColor, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return MyText(
      text: text,
      size: 14,
      weight: FontWeight.w700,
      paddingBottom: 6,
    );
  }
}

class _LockedInfoCard extends StatelessWidget {
  const _LockedInfoCard({
    required this.title,
    required this.content,
    required this.locked,
  });

  final String title;
  final String content;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyText(text: title, size: 12, weight: FontWeight.w700),
              const SizedBox(height: 6),
              Text(
                content,
                style: const TextStyle(fontSize: 12, color: kGreyColor),
              ),
            ],
          ),
        ),
        if (locked)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.6),
                  alignment: Alignment.center,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: const [
                      Icon(Icons.lock, size: 16, color: kGreyColor),
                      Text(
                        'Скрыто до покупки',
                        style: TextStyle(fontSize: 12, color: kGreyColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
            child: MyText(text: title, size: 12, color: kGreyColor),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: MyText(
              text: value,
              size: 12,
              weight: FontWeight.w600,
              textAlign: TextAlign.right,
              maxLines: 2,
              textOverflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
