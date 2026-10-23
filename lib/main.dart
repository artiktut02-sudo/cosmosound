import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _showMsg('Аккаунт создан! Проверь почту.');
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

  void _showPremiumDialog() {
    final TextEditingController _codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CosmoSound Premium 👑'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Слушай без ограничений и поддержи проект!'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(_botUrl);
                  if (await canLaunchUrl(url)) { await launchUrl(url); } 
                  else { _showMsg('Не удалось открыть Telegram'); }
                },
                icon: const Icon(Icons.send),
                label: const Text('Купить в Telegram'),
              ),
              const SizedBox(height: 16),
              const Text('Уже купил? Введи код:'),
              TextField(controller: _codeController, decoration: const InputDecoration(hintText: 'Твой код')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            TextButton(
              onPressed: () {
                final input = _codeController.text.trim();
                if (input == 'CosmoAdmin2077') {
                  setState(() { _isAdmin = true; _isPremium = true; });
                  Navigator.pop(context);
                  _showAdminPanel();
                  return;
                }
                if (input == 'PROMO') {
                  setState(() => _isPremium = true);
                  Navigator.pop(context);
                  _showMsg('Премиум активирован! 👑');
                } else { _showMsg('Неверный код'); }
              },
              child: const Text('Активировать'),
            ),
          ],
        );
      },
    );
  }

  void _showAdminPanel() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Админ-панель 🔐'),
          content: const Text('Добро пожаловать, Создатель.'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() { _favorites.clear(); _isPremium = true; });
                Navigator.pop(context);
                _showMsg('Все данные сброшены, Премиум включен!');
              },
              child: const Text('Сбросить всё + Включить Премиум'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
          ],
        );
      },
    );
  }

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

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выбери оформление'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorOption(Colors.deepPurple, 'Космос'),
              _buildColorOption(Colors.cyan, 'Неон'),
              _buildColorOption(Colors.redAccent, 'Кровавая луна'),
              _buildColorOption(Colors.blue, 'Океан'),
              _buildColorOption(Colors.green, 'Лес'),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
        );
      },
    );
  }

  Widget _buildColorOption(Color color, String name) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color),
      title: Text(name),
      trailing: widget.currentTheme == color ? const Icon(Icons.check) : null,
      onTap: () {
        _changeTheme(color);
        Navigator.pop(context);
        _showMsg('Тема изменена на $name');
      },
    );
  }

  Widget _buildMiniPlayer() {
    if (_currentTrack == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[900], border: Border(top: BorderSide(color: Colors.grey[800]!))),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_currentTrack['title'] ?? 'Без названия', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_currentTrack['artist'] ?? 'Неизвестный', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(icon: Icon(_player.playing ? Icons.pause : Icons.play_arrow, size: 32), onPressed: _togglePlayPause),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [_buildHomePage(), _buildFavoritesPage(), _buildUniversePage()];
    return Scaffold(
      body: Column(children: [Expanded(child: _pages[_currentIndex]), _buildMiniPlayer()]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Музыка'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Избранное'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Вселенная'),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text('CosmoSound 🚀'),
        leading: Builder(builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer())),
        actions: [
          if (_isAdmin) const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.security, color: Colors.green)),
          IconButton(icon: Icon(_isPremium ? Icons.workspace_premium : Icons.star_border, color: _isPremium ? Colors.amber : null), onPressed: _showPremiumDialog),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _allTracks.isEmpty
              ? const Center(child: Text('Нет треков. Загрузи mp3 в папку music на Supabase!'))
              : ListView.builder(
                  itemCount: _allTracks.length,
                  itemBuilder: (context, index) {
                    final track = _allTracks[index];
                    final isFav = _favorites.any((t) => t['id'] == track['id']);
                    return ListTile(
                      title: Text(track['title'] ?? 'Без названия'),
                      subtitle: Text(track['artist'] ?? 'Неизвестный'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null), onPressed: () => _toggleFavorite(track)),
                          IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _playTrack(track)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildFavoritesPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('Избранное ❤️')),
      body: _favorites.isEmpty
          ? const Center(child: Text('Пока пусто. Лайкай треки!'))
          : ListView.builder(
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final track = _favorites[index];
                return ListTile(
                  title: Text(track['title'] ?? 'Без названия'),
                  subtitle: Text(track['artist'] ?? 'Неизвестный'),
                  trailing: IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _playTrack(track)),
                );
              },
            ),
    );
  }

  Widget _buildUniversePage() {
    return Scaffold(
      appBar: AppBar(title: const Text('Моя вселенная 🌌')),
      body: _favorites.isEmpty
          ? const Center(child: Text('Добавь треки в избранное, чтобы создать свою вселенную'))
          : Column(
              children: [
                const Padding(padding: EdgeInsets.all(16.0), child: Text('Твой персональный плейлист', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Expanded(
                  child: ListView.builder(
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final track = _favorites[index];
                      return ListTile(
                        title: Text(track['title'] ?? 'Без названия'),
                        subtitle: Text(track['artist'] ?? 'Неизвестный'),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: () => _playTrack(track),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
