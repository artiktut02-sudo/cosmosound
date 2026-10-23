import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Новая библиотека

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://bgzdbtouckpzwplbzhbn.supabase.co',
    anonKey: 'sb_publishable_yHpdNA3ZD6XY-rjxCHCayQ_NIAUZz9q',
  );
  runApp(const CosmoSoundApp());
}

class CosmoSoundApp extends StatefulWidget {
  const CosmoSoundApp({super.key});

  @override
  State<CosmoSoundApp> createState() => _CosmoSoundAppState();
}

class _CosmoSoundAppState extends State<CosmoSoundApp> {
  Color _themeColor = Colors.deepPurple;
  void _changeTheme(Color color) { setState(() { _themeColor = color; }); }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CosmoSound',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _themeColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// Экран проверки авторизации
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final session = snapshot.data?.session;
        if (session != null) {
          // Пользователь вошел
          return const MainScreen();
        } else {
          // Пользователь не вошел
          return const LoginScreen();
        }
      },
    );
  }
}

// Экран входа/регистрации
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false; // Режим: Вход или Регистрация

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _showMsg('Аккаунт создан! Проверь почту для подтверждения (если нужно).');
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      _showMsg('Ошибка: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 16),
              Text(_isSignUp ? 'Регистрация в CosmoSound' : 'Вход в CosmoSound', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleAuth,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: Text(_isSignUp ? 'Зарегистрироваться' : 'Войти'),
                    ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(_isSignUp ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Основной экран (уже с музыкой и меню)
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<dynamic> _allTracks = [];
  final List<dynamic> _favorites = [];
  bool _isLoading = false;
  
  final AudioPlayer _player = AudioPlayer();
  dynamic _currentTrack; 

  bool _isPremium = false; 
  bool _isAdmin = false; 
  
  final String _botUrl = 'https://t.me/your_bot_name'; 
  final String _channelUrl = 'https://t.me/your_channel_name';

  // Твои ключи для доступа к файлам
  final String _supabaseUrl = 'https://bgzdbtouckpzwplbzhbn.supabase.co'; 
  final String _supabaseKey = 'sb_publishable_yHpdNA3ZD6XY-rjxCHCayQ_NIAUZz9q'; 
  final String _bucketName = 'music';

  @override
  void initState() {
    super.initState();
    _loadTracksFromSupabase();
    
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
        setState(() {}); 
      }
    });
  }

  Future<void> _loadTracksFromSupabase() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('$_supabaseUrl/storage/v1/object/list/$_bucketName');
      
      final response = await http.post(
        url,
        headers: {
          'apikey': _supabaseKey,
          'Authorization': 'Bearer $_supabaseKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "prefix": "",
          "limit": 100,
          "offset": 0,
          "sortBy": {"column": "name", "order": "asc"}
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _allTracks.clear();
          for (var file in data) {
            String fileName = file['name'].toString();
            if (fileName.toLowerCase().endsWith('.mp3')) {
              _allTracks.add({
                'id': fileName,
                'title': fileName.replaceAll('.mp3', '').replaceAll('_', ' '),
                'artist': 'CosmoSound',
                'audio': '$_supabaseUrl/storage/v1/object/public/$_bucketName/$fileName',
              });
            }
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showMsg('Ошибка Supabase: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg('Ошибка сети: $e');
    }
  }

  void _toggleFavorite(dynamic track) {
    setState(() {
      if (_favorites.any((t) => t['id'] == track['id'])) {
        _favorites.removeWhere((t) => t['id'] == track['id']);
        _showMsg('Удалено из избранного');
      } else {
        _favorites.add(track);
        _showMsg('Добавлено в избранное ❤️');
      }
    });
  }

  Future<void> _playTrack(dynamic track) async {
    try {
      setState(() => _currentTrack = track);
      final String? audioUrl = track['audio'];
      if (audioUrl != null && audioUrl.isNotEmpty) {
        await _player.setUrl(audioUrl);
        _player.play();
      } else {
        _showMsg('Нет ссылки на аудио');
      }
      setState(() {}); 
    } catch (e) {
      _showMsg('Ошибка воспроизведения: $e');
    }
  }

  void _togglePlayPause() {
    if (_player.playing) { _player.pause(); } 
    else {
      if (_player.processingState == ProcessingState.completed) { _player.seek(Duration.zero); }
      _player.play();
    }
    setState(() {});
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ... (Дальше идет остальной код интерфейса, меню, премиума и админки, 
  // который я давал в предыдущих сообщениях. Скопируй его сюда, 
  // но в меню добавь кнопку "Выйти")

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.8)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.music_note, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text('CosmoSound', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Оформление'),
            onTap: () { Navigator.pop(context); _showThemeDialog(); },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.send, color: Colors.blue),
            title: const Text('Telegram проект'),
            onTap: () async {
              final url = Uri.parse(_channelUrl);
              if (await canLaunchUrl(url)) { await launchUrl(url); }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('О приложении'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'CosmoSound',
                applicationVersion: '1.0',
                applicationIcon: const Icon(Icons.music_note, size: 40),
                children: const [Text('Твое космическое музыкальное пространство.')],
              );
            },
          ),
          const Divider(),
          // Кнопка ВЫЙТИ
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ... (Остальной код интерфейса остается без изменений)
