import 'package:flutter/material.dart';

import '../sync/supabase_config.dart';
import '../sync/sync_service.dart';

/// Экран синхронизации: вход в общий аккаунт семьи и обмен данными.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _busy = false;
  bool _isError = false;
  String? _status;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _isError = false;
      _status = null;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _status = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run(() async {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        if (email.isEmpty || password.isEmpty) {
          throw const SyncException('Введите e-mail и пароль');
        }
        await SyncService.signIn(email, password);
        if (!mounted) return;
        setState(() => _status = 'Вход выполнен. Теперь нажмите «Синхронизировать».');
      });

  Future<void> _signUp() => _run(() async {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        if (email.isEmpty || password.length < 6) {
          throw const SyncException(
            'Введите e-mail и пароль не короче 6 символов',
          );
        }
        await SyncService.signUp(email, password);
        if (!mounted) return;
        setState(() => _status = 'Аккаунт семьи создан. Запишите email и пароль — '
            'их нужно ввести на остальных телефонах.');
      });

  Future<void> _signOut() => _run(() async {
        await SyncService.signOut();
        if (!mounted) return;
        setState(() => _status = 'Вы вышли из аккаунта. Данные остались на устройстве.');
      });

  Future<void> _sync({bool full = false}) => _run(() async {
        final result = await SyncService.syncAll(full: full);
        if (!mounted) return;

        final lines = <String>[
          'Получено из облака: ${result.pulled}',
          'Отправлено в облако: ${result.pushed}',
        ];
        if (result.hasErrors) {
          lines.add('');
          lines.add('Ошибки:');
          lines.addAll(result.errors.take(5));
        } else if (!result.hadChanges) {
          lines.add('Изменений нет — всё уже синхронизировано.');
        }

        setState(() {
          _isError = result.hasErrors;
          _status = lines.join('\n');
        });
      });

  Widget _buildNotConfigured() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Синхронизация не настроена',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Эта сборка не знает адрес облака: при компиляции не переданы '
              'SUPABASE_URL и SUPABASE_ANON_KEY (либо клиент не смог '
              'инициализироваться). Приложение полностью работает локально, '
              'данные никуда не уходят.',
            ),
            SizedBox(height: 8),
            Text(
              'Чтобы включить: GitHub → Settings → Secrets and variables → '
              'Actions → добавьте SUPABASE_URL и SUPABASE_ANON_KEY, затем '
              'пересоберите APK.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Один аккаунт на всю семью: создаёте его здесь один раз, '
          'а на остальных телефонах просто вводите тот же e-mail и пароль.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'E-mail семьи',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Пароль',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _busy ? null : _signIn,
                child: const Text('Войти'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _signUp,
                child: const Text('Создать семью'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignedIn(String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_done, color: Colors.teal),
            title: Text(
              email,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Аккаунт семьи'),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.sync),
          label: const Text('Синхронизировать'),
          onPressed: _busy ? null : () => _sync(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.cloud_download),
          label: const Text('Полная синхронизация (заново)'),
          onPressed: _busy ? null : () => _sync(full: true),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Выйти из аккаунта'),
          onPressed: _busy ? null : _signOut,
        ),
        const SizedBox(height: 16),
        const Text(
          'Локальные изменения отправляются, а изменения других устройств — '
          'забираются. При конфликте остаётся более поздняя правка.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseConfig.isReady;
    final signedIn = SyncService.isSignedIn;
    final email = SyncService.currentEmail ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Синхронизация')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!configured)
            _buildNotConfigured()
          else if (!signedIn)
            _buildAuthForm()
          else
            _buildSignedIn(email),
          if (configured) ...[
            const SizedBox(height: 20),
            if (_busy)
              const Center(child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              )),
            if (_status != null)
              Card(
                color: _isError ? Colors.red.shade50 : Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _status!,
                    style: TextStyle(
                      color: _isError ? Colors.red.shade900 : Colors.teal.shade900,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
