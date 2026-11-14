# Volkov Family App

Семейный помощник на Flutter (Android): дела, покупки, дни рождения, семья,
фамильное древо, семейный блокнот и Wishlist. Данные хранятся локально в SQLite
(`sqflite`), есть необязательная синхронизация между устройствами через
Supabase (один общий аккаунт семьи).

## Экраны

| Экран | Файл | Что делает |
|---|---|---|
| Главная | `lib/screens/dashboard_screen.dart` | Приветствие, ближайшие ДР, дела на сегодня, быстрые действия |
| Дела | `lib/screens/tasks_screen.dart` | Вкладки «Все / Сегодня / На неделе / Регулярные», показания счётчиков |
| Покупки | `lib/screens/purchases_screen.dart` | «В магазин / На неделе / Глобальные», заметки к покупкам |
| Семья | `lib/screens/family_screen.dart` | Карточки членов семьи, дата рождения, возраст, связи для древа |
| Древо | `lib/screens/family_tree_screen.dart` | Граф поколений с зумом; связи родитель/супруг |
| Заметки | `lib/screens/notes_screen.dart` | Цветные заметки с категориями, фото и поиском |
| Настройки | `lib/screens/settings_screen.dart` | Тема, размер шрифта, категории, синхронизация |
| Календарь | `lib/screens/calendar_screen.dart` | Месячная сетка дел и дней рождения |
| Wishlist | `lib/screens/gifts_screen.dart` | Список желаний по членам семьи |
| Синхронизация | `lib/screens/sync_screen.dart` | Вход в аккаунт семьи и обмен данными |

## Технологии

- Flutter `3.24.0`, Dart `>=3.3.0`
- `sqflite` (SQLite, версия схемы **16**), `path`
- `flutter_local_notifications` + `timezone` — локальные напоминания
- `supabase_flutter` — синхронизация (подключается только при наличии ключей)
- `shared_preferences`, `image_picker`, `url_launcher`, `fl_chart`, `confetti`, `flutter_slidable`
- `flutter_localizations` — русская локализация дат и календаря

## Структура

```
lib/
├── main.dart                  # тема, локализация, регистрация/главный экран
├── db/database_helper.dart    # схема БД, миграции, триггеры синхронизации
├── models/                    # Task, Purchase, Birthday, Gift
├── screens/                   # экраны приложения (включая family_tree_screen)
├── sync/                      # supabase_config, sync_service, sync_db
├── utils/person_utils.dart    # даты, возраст, ФИО
├── utils/notification_service.dart
└── widgets/item_tile.dart

supabase/schema.sql            # SQL для облака (таблица + RLS)
```

## Синхронизация (необязательно)

1. В Supabase → **SQL Editor** выполнить `supabase/schema.sql`
   (таблица `family_data` + политики RLS).
2. Supabase → **Authentication → Sign In / Up → Email** → выключить
   **Confirm email**.
3. GitHub → **Settings → Secrets and variables → Actions** добавить:
   - `SUPABASE_URL` — `https://<project-ref>.supabase.co`
   - `SUPABASE_ANON_KEY` — публичный `anon` (или `publishable`) ключ
4. Пересобрать APK. В приложении: **Настройки → Синхронизация** →
   «Создать семью» (один раз), на остальных телефонах — «Войти».

> `service_role`-ключ приложению не нужен — не добавляйте его никуда.
> Без ключей приложение работает полностью локально, данные в облако не уходят.

## Сборка APK

В репозитории хранятся только `lib/` и `pubspec.yaml`, платформенная папка
`android/` генерируется автоматически в CI:

```bash
# локально
flutter create . --platforms=android --project-name family_lists
flutter pub get
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
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
