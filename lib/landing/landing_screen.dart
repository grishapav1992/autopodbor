import 'package:flutter/material.dart';

import '../auto_request_mock/data.dart';
import '../auto_request_mock/widgets.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 720;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [uiTokens.gray50, Colors.white],
            begin: Alignment.topCenter,
            end: const Alignment(0, 0.6),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: uiTokens.gray900,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Автоподбор',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: uiTokens.gray900,
                                  ),
                                ),
                                Text(
                                  'Подбор авто с проверкой и сопровождением',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: uiTokens.gray600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 8,
                          children: [
                            AppButton(
                              label: 'Войти',
                              variant: ButtonVariant.secondary,
                              onTap: () => Navigator.of(context)
                                  .pushNamed(LoginScreen.routeName),
                            ),
                            AppButton(
                              label: 'Регистрация',
                              onTap: () => Navigator.of(context)
                                  .pushNamed(RegisterScreen.routeName),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Подберите автомобиль без риска',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: uiTokens.gray900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Создайте заявку за пару минут. Автоподборщики предложат варианты, '
                              'а вы выберете лучший по цене и срокам.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: uiTokens.gray600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (isSmall)
                              Column(
                                children: [
                                  AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Прозрачные предложения',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: uiTokens.gray900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Сравнивайте цену, сроки и опыт '
                                          'исполнителей.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: uiTokens.gray600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Проверка авто',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: uiTokens.gray900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Юридическая чистота, состояние, '
                                          'торг и сопровождение сделки.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: uiTokens.gray600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Без лишних звонков',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: uiTokens.gray900,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Все общение и решения — в одном месте.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: uiTokens.gray600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: AppCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Прозрачные предложения',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: uiTokens.gray900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Сравнивайте цену, сроки и опыт '
                                            'исполнителей.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: uiTokens.gray600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Проверка авто',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: uiTokens.gray900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Юридическая чистота, состояние, '
                                            'торг и сопровождение сделки.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: uiTokens.gray600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Без лишних звонков',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: uiTokens.gray900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Все общение и решения — в одном месте.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: uiTokens.gray600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 18),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Как это работает',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: uiTokens.gray900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1. Заполните заявку по авто или под ключ.\n'
                                    '2. Получите предложения автоподборщиков.\n'
                                    '3. Выберите исполнителя и начните работу.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: uiTokens.gray600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (isSmall)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppButton(
                                    label: 'Начать подбор без входа',
                                    onTap: () => Navigator.of(context)
                                        .pushNamed('/app-guest'),
                                  ),
                                  const SizedBox(height: 12),
                                  AppButton(
                                    label: 'Создать аккаунт',
                                    variant: ButtonVariant.secondary,
                                    onTap: () => Navigator.of(context)
                                        .pushNamed(RegisterScreen.routeName),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  AppButton(
                                    label: 'Начать подбор без входа',
                                    onTap: () => Navigator.of(context)
                                        .pushNamed('/app-guest'),
                                  ),
                                  const SizedBox(width: 12),
                                  AppButton(
                                    label: 'Создать аккаунт',
                                    variant: ButtonVariant.secondary,
                                    onTap: () => Navigator.of(context)
                                        .pushNamed(RegisterScreen.routeName),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
