# Volkov Family App

Семейный помощник на Flutter (Android): дела, покупки, дни рождения, семья,
семейный блокнот и Wishlist. Все данные хранятся локально в SQLite (`sqflite`).

## Экраны

| Экран | Файл | Что делает |
|---|---|---|
| Главная | `lib/screens/dashboard_screen.dart` | Приветствие, ближайшие ДР, дела на сегодня, быстрые действия |
| Дела | `lib/screens/tasks_screen.dart` | Вкладки «Все / Сегодня / На неделе / Регулярные», показания счётчиков |
| Покупки | `lib/screens/purchases_screen.dart` | «В магазин / На неделе / Глобальные», заметки к покупкам |
| Семья | `lib/screens/family_screen.dart` | Карточки членов семьи, дата рождения и возраст |
| Заметки | `lib/screens/notes_screen.dart` | Цветные заметки с категориями, фото и поиском |
| Настройки | `lib/screens/settings_screen.dart` | Тема, размер шрифта, категории |
| Календарь | `lib/screens/calendar_screen.dart` | Месячная сетка дел и дней рождения |
| Wishlist | `lib/screens/gifts_screen.dart` | Список желаний по членам семьи |

## Технологии

- Flutter `3.24.0`, Dart `>=3.3.0`
- `sqflite` (SQLite, версия схемы **14**), `path`
- `flutter_local_notifications` + `timezone` — локальные напоминания
- `shared_preferences`, `image_picker`, `url_launcher`, `fl_chart`, `confetti`, `flutter_slidable`
- `flutter_localizations` — русская локализация дат и календаря

## Структура

```
lib/
├── main.dart                  # тема, локализация, регистрация/главный экран
├── db/database_helper.dart    # схема БД и миграции
├── models/                    # Task, Purchase, Birthday, Gift
├── screens/                   # экраны приложения
├── utils/notification_service.dart
└── widgets/item_tile.dart
```

## Сборка APK

В репозитории хранятся только `lib/` и `pubspec.yaml`, платформенная папка
`android/` генерируется автоматически в CI:

```bash
# локально
flutter create . --platforms=android --project-name family_lists
flutter pub get
flutter build apk --release
```

Сборка в GitHub Actions (`.github/workflows/build-apk.yml`) выполняется при
каждом пуше в `main`. Готовый APK — артефакт `family-lists-apk`
(раздел Actions → нужный запуск).

> Для `flutter_local_notifications` 17.x обязательно включён
> **core library desugaring** — воркфлоу добавляет его автоматически.
> Если собираете локально, добавьте в `android/app/build.gradle`:
>
> ```gradle
> android {
>     compileOptions {
>         coreLibraryDesugaringEnabled true
>         sourceCompatibility JavaVersion.VERSION_1_8
>         targetCompatibility JavaVersion.VERSION_1_8
>     }
> }
> dependencies {
>     coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
> }
> ```

## Что было исправлено

Смотрите [CHANGES.md](CHANGES.md) — там подробно по каждому файлу.
