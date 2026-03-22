import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

class SparkJoyNewReportNameScreen extends StatefulWidget {
  const SparkJoyNewReportNameScreen({super.key});

  @override
  State<SparkJoyNewReportNameScreen> createState() =>
      _SparkJoyNewReportNameScreenState();
}

class _SparkJoyNewReportNameScreenState
    extends State<SparkJoyNewReportNameScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _create() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _controller.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Новый отчёт')),
      body: ListView(
        padding: AppSizes.DEFAULT,
        children: [
          const MyText(
            text: 'Название отчёта',
            size: 14,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
            decoration: InputDecoration(
              hintText: 'Например: Toyota Camry для клиента',
              filled: true,
              fillColor: kWhiteColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kSecondaryColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const MyText(
            text: 'Название поможет быстро найти отчёт в списке',
            size: 11,
            color: kGreyColor,
          ),
          const SizedBox(height: 18),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.55,
              child: MyButton(buttonText: 'Создать отчёт', onTap: _create),
            ),
          ),
        ],
      ),
    );
  }
}
