import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

class PersonalDataConsent extends StatelessWidget {
  const PersonalDataConsent({super.key, this.sparkHeader = false});

  final bool sparkHeader;

  static const _serviceName = 'AutoBase';
  static const _operatorName =
      'ИНДИВИДУАЛЬНЫЙ ПРЕДПРИНИМАТЕЛЬ ПАВЛЕНКО ГРИГОРИЙ АЛЕКСАНДРОВИЧ';
  static const _ogrnip = '322237500311981';
  static const _inn = '237305224179';
  static const _operatorPhone = '+7 (952) 816-82-45';
  static const _operatorAddress =
      '353217, Россия, Краснодарский край, Динской р-н, п Южный, '
      'ул Новая, д 2/2, кв 12';
  static const _privacyEmail = 'support@carreports.ru';
  // Единый с PrivacyPolicy._policyUrl рабочий адрес политики (GitHub Pages).
  static const _policyUrl =
      'https://grishapav1992.github.io/autopodbor/privacy.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: simpleAppBar(
        title: 'Согласие на ПДн',
        sparkStyle: sparkHeader,
      ),
      body: ListView(
        shrinkWrap: true,
        padding: AppSizes.listPaddingWithBottomBar(),
        physics: const BouncingScrollPhysics(),
        children: const [
          _ConsentTitle('Согласие на обработку персональных данных'),
          _ConsentParagraph('Версия 1.0 от 02.07.2026'),
          _ConsentParagraph(
            'Нажимая галочку при авторизации в сервисе $_serviceName, я добровольно и осознанно даю согласие на обработку моих персональных данных оператору:',
          ),
          _ConsentParagraph(
            '$_operatorName\n'
            'ОГРНИП: $_ogrnip\n'
            'ИНН: $_inn\n'
            'Телефон: $_operatorPhone\n'
            'Адрес: $_operatorAddress\n'
            'Email для обращений по персональным данным: $_privacyEmail',
          ),
          _ConsentSection(
            title: '1. Какие персональные данные обрабатываются',
            paragraphs: [
              'Я даю согласие на обработку следующих данных:',
              '1.1. номер телефона;',
              '1.2. фамилия, имя и отчество, если я укажу их в профиле;',
              '1.3. сведения об аккаунте, роли, компании, статусе доступа и действиях в сервисе;',
              '1.4. мои персональные данные, которые я сам укажу в профиле, обращениях, отчетах или рабочих материалах;',
              '1.5. технические данные, необходимые для работы и защиты сервиса: IP-адрес, сведения об устройстве, операционной системе, версии приложения, дата и время использования сервиса, журналы событий.',
            ],
          ),
          _ConsentSection(
            title: '2. Цели обработки',
            paragraphs: [
              'Персональные данные обрабатываются для авторизации по телефону, создания и обслуживания аккаунта, предоставления доступа к функциям сервиса, организации работы между компанией, менеджером и авторизованными сотрудниками, создания и хранения отчетов в части, где они содержат мои персональные данные, поддержки пользователей, отправки сервисных уведомлений, обеспечения безопасности сервиса и исполнения требований законодательства Российской Федерации.',
              'Я согласен, что оператор может обезличивать мои персональные данные и использовать обезличенные и агрегированные данные для аналитики, статистики, улучшения сервиса, формирования баз данных и информационных продуктов, если такие данные не позволяют прямо или косвенно определить меня или иное физическое лицо.',
              'Согласие не является согласием на рекламные рассылки.',
            ],
          ),
          _ConsentSection(
            title: '3. Действия с персональными данными',
            paragraphs: [
              'Оператор вправе выполнять следующие действия: сбор, запись, систематизацию, накопление, хранение, уточнение, обновление, изменение, извлечение, использование, предоставление доступа в пределах ролей сервиса, передачу в случаях, указанных в настоящем согласии и Политике, обезличивание, блокирование, удаление и уничтожение.',
              'Обработка может выполняться автоматизированным, неавтоматизированным и смешанным способом.',
            ],
          ),
          _ConsentSection(
            title: '4. Кому могут быть доступны данные',
            paragraphs: [
              'Доступ к данным могут получать оператор, уполномоченные сотрудники и подрядчики оператора, а также менеджеры и сотрудники компании, к которой относится мой аккаунт, задание или отчет, только в объеме, необходимом для работы с заданием, отчетом, поддержкой пользователя или администрированием доступа.',
              'Оператор может поручать обработку данных поставщикам серверной инфраструктуры, объектного хранилища файлов, связи, уведомлений, аналитики стабильности, AI-обработки рабочих материалов и технической поддержки. Такие лица обязаны использовать данные только для порученных целей и обеспечивать их конфиденциальность.',
              'Если я создаю публичную ссылку на отчет, содержащий мои персональные данные, и передаю ее третьим лицам, доступ к отчету получают лица, которым передана эта ссылка.',
              'Обезличенные и агрегированные данные, статистика и производные материалы могут передаваться, предоставляться и реализовываться третьим лицам, если они не позволяют прямо или косвенно определить меня или иное физическое лицо.',
            ],
          ),
          _ConsentSection(
            title: '5. Срок действия согласия',
            paragraphs: [
              'Согласие действует с момента его предоставления и до достижения целей обработки, отзыва согласия, удаления аккаунта либо прекращения обработки персональных данных оператором.',
              'После прекращения обработки данные удаляются, уничтожаются или обезличиваются, если их дальнейшее хранение не требуется по закону или для защиты прав оператора.',
            ],
          ),
          _ConsentSection(
            title: '6. Отзыв согласия',
            paragraphs: [
              'Я могу отозвать согласие, направив обращение на email: $_privacyEmail. В обращении нужно указать данные, позволяющие идентифицировать мой аккаунт, например номер телефона.',
              'Я понимаю, что отказ от предоставления данных или отзыв согласия может сделать невозможной авторизацию и использование функций сервиса.',
            ],
          ),
          _ConsentSection(
            title: '7. Политика обработки персональных данных',
            paragraphs: [
              'До предоставления согласия мне доступна Политика обработки персональных данных в приложении и по адресу: $_policyUrl.',
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsentTitle extends StatelessWidget {
  const _ConsentTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return MyText(
      text: text,
      size: 20,
      weight: FontWeight.w800,
      color: kTertiaryColor,
      lineHeight: 1.2,
      paddingBottom: 16,
    );
  }
}

class _ConsentSection extends StatelessWidget {
  const _ConsentSection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MyText(
            text: title,
            size: 15,
            weight: FontWeight.w700,
            color: kTertiaryColor,
            lineHeight: 1.3,
            paddingBottom: 8,
          ),
          for (final paragraph in paragraphs)
            _ConsentParagraph(paragraph, paddingBottom: 8),
        ],
      ),
    );
  }
}

class _ConsentParagraph extends StatelessWidget {
  const _ConsentParagraph(this.text, {this.paddingBottom = 12});

  final String text;
  final double paddingBottom;

  @override
  Widget build(BuildContext context) {
    return MyText(
      text: text,
      size: 13,
      weight: FontWeight.w500,
      color: kGreyColor,
      lineHeight: 1.45,
      paddingBottom: paddingBottom,
    );
  }
}
