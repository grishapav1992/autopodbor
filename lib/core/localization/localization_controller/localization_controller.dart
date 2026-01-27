import 'package:flutter_application_1/core/localization/translations/en_us.dart';
import 'package:flutter_application_1/core/localization/translations/ru_ru.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class LanguageController extends GetxController {
  static LanguageController instance = Get.find<LanguageController>();

  RxInt currentIndex = RxInt(0);
  RxBool isEnglish = false.obs;

  void onLanguageChanged(String lang, int index) async {
    currentIndex.value = index;
    Localization().selectedLocale(lang);
    await UserSimplePreferences.setLanguageIndex(index);
    isEnglish.value = currentIndex.value == 1;
  }

  getCurrentLocale() {
    if (currentIndex.value == 0) {
      return 'ru';
    } else {
      return 'en';
    }
  }
}

class Localization extends Translations {
  static Locale currentLocale = Locale('ru', 'RU');
  static Locale fallBackLocale = Locale('en', 'US');

  final List<String> languages = ['Русский', 'Английский'];

  final List<Locale> locales = [Locale('ru', 'RU'), Locale('en', 'US')];

  void selectedLocale(String lang) {
    final locale = _getLocaleFromLanguage(lang);
    currentLocale = locale;
    Get.updateLocale(currentLocale);
  }

  Locale _getLocaleFromLanguage(String lang) {
    for (int i = 0; i < languages.length; i++) {
      if (lang == languages[i]) {
        return locales[i];
      }
    }
    return Get.locale!;
  }

  @override
  Map<String, Map<String, String>> get keys => {'ru_RU': ruRu, 'en_US': enUS};
}
