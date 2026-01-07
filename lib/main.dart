import 'package:flutter/material.dart';

enum RequestType {
  specificCar('Конкретный автомобиль'),
  listOfCars('Список автомобилей'),
  classSearch('Подбор по классу');

  const RequestType(this.label);

  final String label;
}

void main() {
  runApp(const AutopodborApp());
}

class AutopodborApp extends StatelessWidget {
  const AutopodborApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Автоподбор — создание заявки',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const RequestFormPage(),
    );
  }
}

class RequestFormPage extends StatefulWidget {
  const RequestFormPage({super.key});

  @override
  State<RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends State<RequestFormPage> {
  RequestType _requestType = RequestType.specificCar;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _status = 'DRAFT';

  @override
  void dispose() {
    _locationController.dispose();
    _budgetController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String get _previewTitle {
    switch (_requestType) {
      case RequestType.specificCar:
        return 'Осмотр по VIN ...';
      case RequestType.listOfCars:
        return 'Список авто: 0 шт.';
      case RequestType.classSearch:
        return 'Подбор по классу';
    }
  }

  String get _previewLocation {
    if (_locationController.text.trim().isEmpty) {
      return 'Город не выбран';
    }
    return _locationController.text.trim();
  }

  String get _previewBudget {
    if (_budgetController.text.trim().isEmpty) {
      return 'Бюджет не указан';
    }
    return 'Бюджет: ${_budgetController.text.trim()} ₽';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(status: _status),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: '1. Тип заявки',
                    child: Column(
                      children: RequestType.values
                          .map(
                            (type) => RadioListTile<RequestType>(
                              title: Text(type.label),
                              subtitle: Text(_typeSubtitle(type)),
                              value: type,
                              groupValue: _requestType,
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _requestType = value;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: '2. Общие данные',
                    child: Column(
                      children: [
                        _FieldGrid(
                          children: [
                            _LabeledField(
                              label: 'Город / регион осмотра *',
                              child: TextField(
                                controller: _locationController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'Например, Москва',
                                ),
                              ),
                            ),
                            _LabeledField(
                              label: 'Тип услуги',
                              child: DropdownButtonFormField<String>(
                                value: 'one_time',
                                items: const [
                                  DropdownMenuItem(
                                    value: 'one_time',
                                    child: Text('Разовый осмотр'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'full_search',
                                    child: Text('Подбор под ключ'),
                                  ),
                                ],
                                onChanged: (_) {},
                              ),
                            ),
                            _LabeledField(
                              label: 'Бюджет (₽)',
                              child: TextField(
                                controller: _budgetController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  hintText: 'от 1 000 000',
                                ),
                              ),
                            ),
                            _LabeledField(
                              label: 'Сроки',
                              child: DropdownButtonFormField<String>(
                                value: 'today',
                                items: const [
                                  DropdownMenuItem(
                                    value: 'today',
                                    child: Text('Сегодня'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'week',
                                    child: Text('В течение недели'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'no_deadline',
                                    child: Text('Без срока'),
                                  ),
                                ],
                                onChanged: (_) {},
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _LabeledField(
                          label: 'Комментарий',
                          child: TextField(
                            controller: _commentController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Опишите пожелания или детали',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_requestType == RequestType.specificCar)
                    _SpecificCarSection()
                  else if (_requestType == RequestType.listOfCars)
                    _ListOfCarsSection()
                  else
                    _ClassSearchSection(),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: '4. Предпросмотр карточки в “Мои заявки”',
                    child: _PreviewCard(
                      title: _previewTitle,
                      location: _previewLocation,
                      budget: _previewBudget,
                      status: _status,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _status = 'DRAFT';
                          });
                        },
                        child: const Text('Сохранить черновик'),
                      ),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _status = 'PUBLISHED';
                          });
                        },
                        child: const Text('Отправить заявку'),
                      ),
                      const Text(
                        'После отправки статус сменится на PUBLISHED.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _typeSubtitle(RequestType type) {
    switch (type) {
      case RequestType.specificCar:
        return 'VIN / ссылка / госномер';
      case RequestType.listOfCars:
        return 'несколько авто / VIN / ссылки';
      case RequestType.classSearch:
        return 'класс, бюджет, критерии';
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 16,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Прототип MVP',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Создание заявки на автоподбор',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            SizedBox(
              width: 560,
              child: Text(
                'Одна точка входа с разными формами: конкретное авто, список вариантов или подбор по классу.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x142563EB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('Статус после отправки: $status'),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map(
                (child) => SizedBox(
                  width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SpecificCarSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '3. Конкретная машина',
      child: _FieldGrid(
        children: const [
          _LabeledField(
            label: 'VIN / ссылка / госномер *',
            child: TextField(
              decoration: InputDecoration(
                hintText: 'VIN, ссылка или госномер',
              ),
            ),
          ),
          _LabeledField(
            label: 'Марка / модель / год',
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Toyota Camry 2019',
              ),
            ),
          ),
          _LabeledField(
            label: 'Контакт продавца',
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Телефон или мессенджер',
              ),
            ),
          ),
          _LabeledField(
            label: 'Где находится авто',
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Адрес или район',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListOfCarsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '3. Список машин',
      child: Column(
        children: const [
          _LabeledField(
            label: 'Ссылки / VIN / госномера *',
            child: TextField(
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Каждая строка — отдельная машина',
              ),
            ),
          ),
          SizedBox(height: 16),
          _FieldGrid(
            children: [
              _LabeledField(
                label: 'Максимум вариантов',
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Например, 5',
                  ),
                ),
              ),
              _LabeledField(
                label: 'Приоритеты',
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Сначала Toyota, потом BMW',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassSearchSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '3. Подбор по классу',
      child: Column(
        children: [
          _FieldGrid(
            children: [
              _LabeledField(
                label: 'Класс *',
                child: DropdownButtonFormField<String>(
                  value: '',
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Выберите класс')),
                    DropdownMenuItem(value: 'econom', child: Text('Эконом')),
                    DropdownMenuItem(value: 'comfort', child: Text('Комфорт')),
                    DropdownMenuItem(value: 'business', child: Text('Бизнес')),
                    DropdownMenuItem(value: 'premium', child: Text('Премиум')),
                    DropdownMenuItem(value: 'suv', child: Text('SUV')),
                  ],
                  onChanged: (_) {},
                ),
              ),
              _LabeledField(
                label: 'Бюджет *',
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'от 1 500 000',
                  ),
                ),
              ),
              _LabeledField(
                label: 'Год от',
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '2018',
                  ),
                ),
              ),
              _LabeledField(
                label: 'Год до',
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '2024',
                  ),
                ),
              ),
              _LabeledField(
                label: 'Пробег до (км)',
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'до 80 000',
                  ),
                ),
              ),
              _LabeledField(
                label: 'Коробка / привод / кузов',
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Автомат, полный привод, седан',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _LabeledField(
            label: 'Запреты',
            child: TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Не такси, не битые силовые элементы, не более 2 владельцев',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.location,
    required this.budget,
    required this.status,
  });

  final String title;
  final String location;
  final String budget;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  children: [
                    Text(location, style: const TextStyle(color: Color(0xFF6B7280))),
                    Text(budget, style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4338CA)),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Предложений: 0', style: TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}
