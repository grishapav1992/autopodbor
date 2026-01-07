import 'package:flutter/material.dart';

enum RequestType {
  specificCar('Конкретный автомобиль'),
  listOfCars('Список автомобилей'),
  classSearch('Подбор по классу');

  const RequestType(this.label);

  final String label;
}

enum RequestStatus {
  draft('Черновик'),
  published('Создана'),
  hasOffers('Есть предложения'),
  proSelected('Исполнитель выбран'),
  inProgress('В работе'),
  completed('Завершена'),
  cancelled('Отменена'),
  dispute('Спор');

  const RequestStatus(this.label);

  final String label;
}

enum AppTab { create, my }

class AutoRequest {
  AutoRequest({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.status,
    required this.city,
    required this.serviceType,
    this.budgetFrom,
    this.budgetTo,
    this.deadlineText,
    this.comment,
    this.vin,
    this.link,
    this.make,
    this.model,
    this.year,
    this.carsCount,
    this.carsBulkText,
    this.carClass,
    this.yearFrom,
    this.yearTo,
    this.mileageTo,
  });

  final String id;
  final DateTime createdAt;
  final RequestType type;
  final RequestStatus status;

  final String city;
  final String serviceType;
  final String? budgetFrom;
  final String? budgetTo;
  final String? deadlineText;
  final String? comment;

  final String? vin;
  final String? link;
  final String? make;
  final String? model;
  final String? year;

  final String? carsCount;
  final String? carsBulkText;

  final String? carClass;
  final String? yearFrom;
  final String? yearTo;
  final String? mileageTo;

  AutoRequest copyWith({
    RequestStatus? status,
  }) {
    return AutoRequest(
      id: id,
      createdAt: createdAt,
      type: type,
      status: status ?? this.status,
      city: city,
      serviceType: serviceType,
      budgetFrom: budgetFrom,
      budgetTo: budgetTo,
      deadlineText: deadlineText,
      comment: comment,
      vin: vin,
      link: link,
      make: make,
      model: model,
      year: year,
      carsCount: carsCount,
      carsBulkText: carsBulkText,
      carClass: carClass,
      yearFrom: yearFrom,
      yearTo: yearTo,
      mileageTo: mileageTo,
    );
  }
}

void main() {
  runApp(const AutopodborApp());
}

class AutopodborApp extends StatelessWidget {
  const AutopodborApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Автоподбор — прототип',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF111827)),
        useMaterial3: true,
      ),
      home: const RequestPrototypePage(),
    );
  }
}

class RequestPrototypePage extends StatefulWidget {
  const RequestPrototypePage({super.key});

  @override
  State<RequestPrototypePage> createState() => _RequestPrototypePageState();
}

class _RequestPrototypePageState extends State<RequestPrototypePage> {
  AppTab _tab = AppTab.create;
  int _step = 1;
  final int _totalSteps = 3;

  RequestType _type = RequestType.specificCar;

  final TextEditingController _cityController = TextEditingController(text: 'Алматы');
  String _serviceType = 'Разовый осмотр';
  final TextEditingController _budgetFromController = TextEditingController();
  final TextEditingController _budgetToController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  final TextEditingController _vinController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  String? _carsCount;
  final TextEditingController _carsBulkController = TextEditingController();

  String _carClass = 'Бизнес-класс';
  final TextEditingController _yearFromController = TextEditingController(text: '2018');
  final TextEditingController _yearToController = TextEditingController(text: '2022');
  final TextEditingController _mileageController = TextEditingController(text: '120000');

  final List<AutoRequest> _requests = [
    AutoRequest(
      id: 'REQ-100001',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      type: RequestType.classSearch,
      status: RequestStatus.hasOffers,
      city: 'Алматы',
      serviceType: 'Подбор под ключ',
      budgetFrom: '9000000',
      deadlineText: 'В течение недели',
      comment: 'Без такси, без силовых ремонтов.',
      carClass: 'Бизнес-класс',
      yearFrom: '2018',
      yearTo: '2022',
      mileageTo: '120000',
    ),
  ];

  @override
  void dispose() {
    _cityController.dispose();
    _budgetFromController.dispose();
    _budgetToController.dispose();
    _deadlineController.dispose();
    _commentController.dispose();
    _vinController.dispose();
    _linkController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _carsBulkController.dispose();
    _yearFromController.dispose();
    _yearToController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  String get _budgetPreview {
    final from = _budgetFromController.text.trim();
    final to = _budgetToController.text.trim();
    if (from.isEmpty && to.isEmpty) {
      return '—';
    }
    if (from.isNotEmpty && to.isNotEmpty) {
      return 'от $from до $to ₽';
    }
    if (from.isNotEmpty) {
      return 'от $from ₽';
    }
    return 'до $to ₽';
  }

  AutoRequest get _currentPreview {
    return AutoRequest(
      id: '—',
      createdAt: DateTime.now(),
      type: _type,
      status: RequestStatus.published,
      city: _cityController.text.trim(),
      serviceType: _serviceType,
      budgetFrom: _budgetFromController.text.trim().isEmpty ? null : _budgetFromController.text.trim(),
      budgetTo: _budgetToController.text.trim().isEmpty ? null : _budgetToController.text.trim(),
      deadlineText: _deadlineController.text.trim().isEmpty ? null : _deadlineController.text.trim(),
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      vin: _type == RequestType.specificCar ? _vinController.text.trim() : null,
      link: _type == RequestType.specificCar ? _linkController.text.trim() : null,
      make: _type == RequestType.specificCar ? _makeController.text.trim() : null,
      model: _type == RequestType.specificCar ? _modelController.text.trim() : null,
      year: _type == RequestType.specificCar ? _yearController.text.trim() : null,
      carsCount: _type == RequestType.listOfCars ? _carsCount : null,
      carsBulkText: _type == RequestType.listOfCars ? _carsBulkController.text.trim() : null,
      carClass: _type == RequestType.classSearch ? _carClass : null,
      yearFrom: _type == RequestType.classSearch ? _yearFromController.text.trim() : null,
      yearTo: _type == RequestType.classSearch ? _yearToController.text.trim() : null,
      mileageTo: _type == RequestType.classSearch ? _mileageController.text.trim() : null,
    );
  }

  void _resetWizard() {
    setState(() {
      _step = 1;
      _type = RequestType.specificCar;
      _cityController.text = 'Алматы';
      _serviceType = 'Разовый осмотр';
      _budgetFromController.clear();
      _budgetToController.clear();
      _deadlineController.clear();
      _commentController.clear();
      _vinController.clear();
      _linkController.clear();
      _makeController.clear();
      _modelController.clear();
      _yearController.clear();
      _carsCount = null;
      _carsBulkController.clear();
      _carClass = 'Бизнес-класс';
      _yearFromController.text = '2018';
      _yearToController.text = '2022';
      _mileageController.text = '120000';
    });
  }

  void _createRequest() {
    setState(() {
      _requests.insert(
        0,
        AutoRequest(
          id: _generateId(),
          createdAt: DateTime.now(),
          type: _type,
          status: RequestStatus.published,
          city: _cityController.text.trim(),
          serviceType: _serviceType,
          budgetFrom: _budgetFromController.text.trim().isEmpty ? null : _budgetFromController.text.trim(),
          budgetTo: _budgetToController.text.trim().isEmpty ? null : _budgetToController.text.trim(),
          deadlineText: _deadlineController.text.trim().isEmpty ? null : _deadlineController.text.trim(),
          comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
          vin: _type == RequestType.specificCar ? _vinController.text.trim() : null,
          link: _type == RequestType.specificCar ? _linkController.text.trim() : null,
          make: _type == RequestType.specificCar ? _makeController.text.trim() : null,
          model: _type == RequestType.specificCar ? _modelController.text.trim() : null,
          year: _type == RequestType.specificCar ? _yearController.text.trim() : null,
          carsCount: _type == RequestType.listOfCars ? _carsCount : null,
          carsBulkText: _type == RequestType.listOfCars ? _carsBulkController.text.trim() : null,
          carClass: _type == RequestType.classSearch ? _carClass : null,
          yearFrom: _type == RequestType.classSearch ? _yearFromController.text.trim() : null,
          yearTo: _type == RequestType.classSearch ? _yearToController.text.trim() : null,
          mileageTo: _type == RequestType.classSearch ? _mileageController.text.trim() : null,
        ),
      );
      _tab = AppTab.my;
      _resetWizard();
    });
  }

  void _next() {
    if (_step < _totalSteps) {
      setState(() {
        _step += 1;
      });
      return;
    }
    _createRequest();
  }

  void _back() {
    setState(() {
      _step = _step > 1 ? _step - 1 : 1;
    });
  }

  void _updateStatus(AutoRequest request, RequestStatus status) {
    setState(() {
      final index = _requests.indexWhere((item) => item.id == request.id);
      if (index == -1) {
        return;
      }
      _requests[index] = _requests[index].copyWith(status: status);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _TopBar(
                  tab: _tab,
                  requestsCount: _requests.length,
                  onTabChanged: (tab) => setState(() => _tab = tab),
                ),
                const SizedBox(height: 16),
                if (_tab == AppTab.create) _buildCreate() else _buildMyRequests(),
                const SizedBox(height: 16),
                const Text(
                  'Примечание: это мок без API. Данные хранятся в памяти страницы; после перезагрузки пропадут.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreate() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: _step, total: _totalSteps),
          const SizedBox(height: 12),
          if (_step == 1) _buildStepOne(),
          if (_step == 2) _buildStepTwo(),
          if (_step == 3) _buildStepThree(),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: _step == 1 ? _resetWizard : _back,
                child: Text(_step == 1 ? 'Сбросить' : 'Назад'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => setState(() => _tab = AppTab.my),
                child: const Text('Перейти в “Мои заявки”'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _next,
                child: Text(_step < _totalSteps ? 'Далее' : 'Создать заявку'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledField(
          label: 'Тип заявки',
          required: true,
          child: DropdownButtonFormField<RequestType>(
            value: _type,
            items: RequestType.values
                .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
        ),
        const SizedBox(height: 12),
        _LabeledField(
          label: 'Город / регион осмотра',
          required: true,
          child: TextField(
            controller: _cityController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Например: Алматы'),
          ),
        ),
        const SizedBox(height: 12),
        _LabeledField(
          label: 'Тип услуги',
          child: DropdownButtonFormField<String>(
            value: _serviceType,
            items: const [
              DropdownMenuItem(value: 'Разовый осмотр', child: Text('Разовый осмотр')),
              DropdownMenuItem(value: 'Подбор под ключ', child: Text('Подбор под ключ')),
            ],
            onChanged: (value) => setState(() => _serviceType = value ?? _serviceType),
          ),
        ),
        const SizedBox(height: 12),
        _FieldGrid(
          children: [
            _LabeledField(
              label: 'Бюджет от (₽)',
              child: TextField(
                controller: _budgetFromController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Например: 2 500 000'),
              ),
            ),
            _LabeledField(
              label: 'Бюджет до (₽)',
              child: TextField(
                controller: _budgetToController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Например: 3 500 000'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LabeledField(
          label: 'Сроки',
          child: TextField(
            controller: _deadlineController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'В течение недели'),
          ),
        ),
        const SizedBox(height: 12),
        _LabeledField(
          label: 'Комментарий',
          child: TextField(
            controller: _commentController,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Опишите пожелания, ограничения, важные детали',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Тип: ${_type.label}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        if (_type == RequestType.specificCar) ...[
          _FieldGrid(
            children: [
              _LabeledField(
                label: 'VIN номер',
                required: true,
                child: TextField(
                  controller: _vinController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Например, XW8ZZZ...'),
                ),
              ),
              _LabeledField(
                label: 'Ссылка на объявление',
                child: TextField(
                  controller: _linkController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'https://auto.ru/...'),
                ),
              ),
              _LabeledField(
                label: 'Марка',
                child: TextField(
                  controller: _makeController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Toyota'),
                ),
              ),
              _LabeledField(
                label: 'Модель',
                child: TextField(
                  controller: _modelController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Camry'),
                ),
              ),
              _LabeledField(
                label: 'Год выпуска',
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '2019'),
                ),
              ),
            ],
          ),
        ],
        if (_type == RequestType.listOfCars) ...[
          _LabeledField(
            label: 'Сколько вариантов посмотреть?',
            required: true,
            child: DropdownButtonFormField<String>(
              value: _carsCount,
              hint: const Text('Выберите количество'),
              items: const [
                DropdownMenuItem(value: '1', child: Text('1 вариант')),
                DropdownMenuItem(value: '2', child: Text('2 варианта')),
                DropdownMenuItem(value: '3', child: Text('3 варианта')),
                DropdownMenuItem(value: '5', child: Text('5 вариантов')),
                DropdownMenuItem(value: '10', child: Text('10 вариантов')),
              ],
              onChanged: (value) => setState(() => _carsCount = value),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: 'Список автомобилей (необязательно)',
            child: TextField(
              controller: _carsBulkController,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Если уже есть варианты, добавьте ссылки или VIN',
              ),
            ),
          ),
        ],
        if (_type == RequestType.classSearch) ...[
          _LabeledField(
            label: 'Класс автомобиля',
            required: true,
            child: DropdownButtonFormField<String>(
              value: _carClass,
              items: const [
                DropdownMenuItem(value: 'Эконом', child: Text('Эконом')),
                DropdownMenuItem(value: 'Комфорт', child: Text('Комфорт')),
                DropdownMenuItem(value: 'Бизнес-класс', child: Text('Бизнес-класс')),
                DropdownMenuItem(value: 'Премиум', child: Text('Премиум')),
                DropdownMenuItem(value: 'SUV', child: Text('SUV')),
              ],
              onChanged: (value) => setState(() => _carClass = value ?? _carClass),
            ),
          ),
          const SizedBox(height: 12),
          _FieldGrid(
            children: [
              _LabeledField(
                label: 'Год от',
                child: TextField(
                  controller: _yearFromController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '2018'),
                ),
              ),
              _LabeledField(
                label: 'Год до',
                child: TextField(
                  controller: _yearToController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '2022'),
                ),
              ),
              _LabeledField(
                label: 'Пробег до (км)',
                child: TextField(
                  controller: _mileageController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: '120000'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStepThree() {
    final preview = _currentPreview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Проверьте данные — после создания заявка появится в разделе “Мои заявки” со статусом “Создана”.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreviewRow(title: 'Тип заявки', value: preview.type.label),
              _PreviewRow(title: 'Город', value: preview.city.isEmpty ? '—' : preview.city),
              _PreviewRow(title: 'Тип услуги', value: preview.serviceType),
              _PreviewRow(title: 'Бюджет', value: _budgetPreview),
              _PreviewRow(title: 'Сроки', value: preview.deadlineText ?? '—'),
              _PreviewRow(title: 'Комментарий', value: preview.comment ?? '—'),
              const SizedBox(height: 8),
              const Text('Детали по типу', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_type == RequestType.specificCar) ...[
                _PreviewRow(title: 'VIN', value: preview.vin ?? '—'),
                _PreviewRow(title: 'Ссылка', value: preview.link ?? '—'),
                _PreviewRow(
                  title: 'Марка/модель/год',
                  value: '${preview.make ?? '—'} ${preview.model ?? ''} ${preview.year ?? ''}'.trim(),
                ),
              ],
              if (_type == RequestType.listOfCars) ...[
                _PreviewRow(title: 'Количество вариантов', value: preview.carsCount ?? '—'),
                _PreviewRow(title: 'Список', value: preview.carsBulkText ?? '—'),
              ],
              if (_type == RequestType.classSearch) ...[
                _PreviewRow(title: 'Класс', value: preview.carClass ?? '—'),
                _PreviewRow(
                  title: 'Год от/до',
                  value: '${preview.yearFrom ?? '—'} / ${preview.yearTo ?? '—'}',
                ),
                _PreviewRow(title: 'Пробег до', value: preview.mileageTo ?? '—'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyRequests() {
    if (_requests.isEmpty) {
      return const _Card(
        child: Text('Пока нет заявок.', style: TextStyle(color: Color(0xFF6B7280))),
      );
    }
    return Column(
      children: _requests.map(_buildRequestCard).toList(),
    );
  }

  Widget _buildRequestCard(AutoRequest request) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _requestTitle(request),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.city} • ${request.serviceType} • Бюджет: ${_formatBudget(request)}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDateTime(request.createdAt),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: request.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statusActions(request),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('Детали заявки', style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                _PreviewRow(title: 'Тип', value: request.type.label),
                _PreviewRow(title: 'Сроки', value: request.deadlineText ?? '—'),
                _PreviewRow(title: 'Комментарий', value: request.comment ?? '—'),
                if (request.type == RequestType.specificCar) ...[
                  _PreviewRow(title: 'VIN', value: request.vin ?? '—'),
                  _PreviewRow(title: 'Ссылка', value: request.link ?? '—'),
                  _PreviewRow(
                    title: 'Марка/модель/год',
                    value: '${request.make ?? '—'} ${request.model ?? ''} ${request.year ?? ''}'.trim(),
                  ),
                ],
                if (request.type == RequestType.listOfCars) ...[
                  _PreviewRow(title: 'Кол-во вариантов', value: request.carsCount ?? '—'),
                  _PreviewRow(title: 'Список', value: request.carsBulkText ?? '—'),
                ],
                if (request.type == RequestType.classSearch) ...[
                  _PreviewRow(title: 'Класс', value: request.carClass ?? '—'),
                  _PreviewRow(
                    title: 'Год от/до',
                    value: '${request.yearFrom ?? '—'} / ${request.yearTo ?? '—'}',
                  ),
                  _PreviewRow(title: 'Пробег до', value: request.mileageTo ?? '—'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statusActions(AutoRequest request) {
    switch (request.status) {
      case RequestStatus.published:
        return [
          OutlinedButton(
            onPressed: () => _updateStatus(request, RequestStatus.cancelled),
            child: const Text('Отменить'),
          ),
          FilledButton(
            onPressed: () => _updateStatus(request, RequestStatus.hasOffers),
            child: const Text('Имитировать “Есть предложения”'),
          ),
        ];
      case RequestStatus.hasOffers:
        return [
          OutlinedButton(
            onPressed: () => _updateStatus(request, RequestStatus.published),
            child: const Text('Вернуть в “Создана”'),
          ),
          FilledButton(
            onPressed: () => _updateStatus(request, RequestStatus.proSelected),
            child: const Text('Имитировать “Исполнитель выбран”'),
          ),
        ];
      case RequestStatus.proSelected:
        return [
          OutlinedButton(
            onPressed: () => _updateStatus(request, RequestStatus.hasOffers),
            child: const Text('Назад к предложениям'),
          ),
          FilledButton(
            onPressed: () => _updateStatus(request, RequestStatus.inProgress),
            child: const Text('Имитировать “Оплачено / В работе”'),
          ),
        ];
      case RequestStatus.inProgress:
        return [
          OutlinedButton(
            onPressed: () => _updateStatus(request, RequestStatus.dispute),
            child: const Text('Перевести в “Спор”'),
          ),
          FilledButton(
            onPressed: () => _updateStatus(request, RequestStatus.completed),
            child: const Text('Имитировать “Завершена”'),
          ),
        ];
      case RequestStatus.completed:
      case RequestStatus.cancelled:
      case RequestStatus.dispute:
        return [
          OutlinedButton(
            onPressed: () => _updateStatus(request, RequestStatus.published),
            child: const Text('Сбросить в “Создана”'),
          ),
        ];
      case RequestStatus.draft:
        return [
          FilledButton(
            onPressed: () => _updateStatus(request, RequestStatus.published),
            child: const Text('Опубликовать'),
          ),
        ];
    }
  }

  String _requestTitle(AutoRequest request) {
    switch (request.type) {
      case RequestType.specificCar:
        return 'Осмотр: ${request.vin ?? '—'}';
      case RequestType.listOfCars:
        return 'Список авто: ${request.carsCount ?? '—'} вариант(ов)';
      case RequestType.classSearch:
        return 'Подбор: ${request.carClass ?? '—'}';
    }
  }

  String _formatBudget(AutoRequest request) {
    if (request.budgetFrom == null && request.budgetTo == null) {
      return '—';
    }
    if (request.budgetFrom != null && request.budgetTo != null) {
      return 'от ${request.budgetFrom} до ${request.budgetTo} ₽';
    }
    if (request.budgetFrom != null) {
      return 'от ${request.budgetFrom} ₽';
    }
    return 'до ${request.budgetTo} ₽';
  }

  String _formatDateTime(DateTime dateTime) {
    final date = '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return 'REQ-${now.toString().substring(now.toString().length - 6)}';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.tab,
    required this.requestsCount,
    required this.onTabChanged,
  });

  final AppTab tab;
  final int requestsCount;
  final ValueChanged<AppTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Автоподбор', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('Web мок: заявка + мои заявки', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
        const Spacer(),
        Wrap(
          spacing: 8,
          children: [
            _TabButton(
              label: 'Создать заявку',
              isActive: tab == AppTab.create,
              onPressed: () => onTabChanged(AppTab.create),
            ),
            _TabButton(
              label: 'Мои заявки ($requestsCount)',
              isActive: tab == AppTab.my,
              onPressed: () => onTabChanged(AppTab.my),
            ),
          ],
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return isActive
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Создать заявку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Text('Шаг $step / $total', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x140F172A), blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w600),
            children: required
                ? const [
                    TextSpan(text: ' *', style: TextStyle(color: Color(0xFFDC2626))),
                  ]
                : const [],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
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
        final isWide = constraints.maxWidth > 680;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map(
                (child) => SizedBox(
                  width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final RequestStatus status;

  Color get _color {
    switch (status) {
      case RequestStatus.draft:
        return const Color(0xFF6B7280);
      case RequestStatus.published:
        return const Color(0xFF334155);
      case RequestStatus.hasOffers:
        return const Color(0xFF2563EB);
      case RequestStatus.proSelected:
        return const Color(0xFF4F46E5);
      case RequestStatus.inProgress:
        return const Color(0xFFF59E0B);
      case RequestStatus.completed:
        return const Color(0xFF16A34A);
      case RequestStatus.cancelled:
        return const Color(0xFFDC2626);
      case RequestStatus.dispute:
        return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
