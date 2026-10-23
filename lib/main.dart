import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const CosmoSoundApp());

class CosmoSoundApp extends StatefulWidget {
  const CosmoSoundApp({super.key});

  @override
  State<CosmoSoundApp> createState() => _CosmoSoundAppState();
}

class _CosmoSoundAppState extends State<CosmoSoundApp> {
  // Выбранный цвет темы
  Color _themeColor = Colors.deepPurple;

  void _changeTheme(Color color) {
    setState(() {
      _themeColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CosmoSound',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _themeColor, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: MainScreen(onThemeChanged: _changeTheme, currentTheme: _themeColor),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(Color) onThemeChanged;
  final Color currentTheme;

  const MainScreen({super.key, required this.onThemeChanged, required this.currentTheme});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<dynamic> _searchTracks = [];
  final List<dynamic> _favorites = [];
  bool _isLoading = false;
  final AudioPlayer _player = AudioPlayer();
  
  bool _isPremium = false; 
  bool _isAdmin = false; 
  
  final String _botUrl = 'https://t.me/your_bot_name'; 
  final String _channelUrl = 'https://t.me/your_channel_name'; // Ссылка на твой канал

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    final String apiHost = 'https://discoveryprovider.audius.co';
    final url = Uri.parse('$apiHost/v1/tracks/trending?app_name=CosmoSound&limit=20');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchTracks.clear();
          _searchTracks.addAll(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showMsg('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg('Ошибка сети: $e');
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    final String apiHost = 'https://discoveryprovider.audius.co';
    final url = Uri.parse('$apiHost/v1/tracks/search?query=$query&app_name=CosmoSound');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchTracks.clear();
          _searchTracks.addAll(data['data'] ?? []);
          _isLoading = false;
        });
        if (_searchTracks.isEmpty) _showMsg('Ничего не найдено');
      } else {
        setState(() => _isLoading = false);
        _showMsg('Ошибка сервера: ${response.statusCode}');
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
      final String apiHost = 'https://discoveryprovider.audius.co';
      final url = Uri.parse('$apiHost/v1/tracks/${track['id']}/stream?app_name=CosmoSound');
      await _player.setUrl(url.toString());
      _player.play();
    } catch (e) {
      _showMsg('Ошибка воспроизведения: $e');
    }
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
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    _showMsg('Не удалось открыть Telegram');
                  }
                },
                icon: const Icon(Icons.send),
                label: const Text('Купить в Telegram'),
              ),
              const SizedBox(height: 16),
              const Text('Уже купил? Введи код:'),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(hintText: 'Твой код'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final input = _codeController.text.trim();
                
                if (input == 'CosmoAdmin2077') {
                  setState(() {
                    _isAdmin = true;
                    _isPremium = true; 
                  });
                  Navigator.pop(context);
                  _showAdminPanel();
                  return;
                }

                if (input == 'PROMO') {
                  setState(() => _isPremium = true);
                  Navigator.pop(context);
                  _showMsg('Премиум активирован! 👑');
                } else {
                  _showMsg('Неверный код');
                }
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
                setState(() {
                  _favorites.clear();
                  _searchTracks.clear();
                  _isPremium = true;
                });
                Navigator.pop(context);
                _showMsg('Все данные сброшены, Премиум включен!');
              },
              child: const Text('Сбросить всё + Включить Премиум'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  // Боковое меню (Drawer)
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: widget.currentTheme.withOpacity(0.8)),
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
            onTap: () {
              Navigator.pop(context); // Закрываем меню
              _showThemeDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.send, color: Colors.blue),
            title: const Text('Telegram проект'),
            onTap: () async {
              final url = Uri.parse(_channelUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
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
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.music_note, size: 40),
                children: [
                  const Text('Твое космическое музыкальное пространство. Слушай, лайкай и создавай свою вселенную.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Окно выбора цвета
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
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
        widget.onThemeChanged(color);
        Navigator.pop(context);
        _showMsg('Тема изменена на $name');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildSearchPage(),
      _buildFavoritesPage(),
      _buildUniversePage(),
    ];

    return Scaffold(
      drawer: _buildDrawer(), // Добавили боковое меню
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Поиск'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Избранное'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Вселенная'),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CosmoSound 🚀'),
        actions: [
          if (_isAdmin)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.security, color: Colors.green),
            ),
          IconButton(
            icon: Icon(_isPremium ? Icons.workspace_premium : Icons.star_border, color: _isPremium ? Colors.amber : null),
            onPressed: _showPremiumDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Найти трек...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _search,
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _searchTracks.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.music_note, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Популярное сейчас', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadTrending,
                          child: const Text('Обновить'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchTracks.length,
                    itemBuilder: (context, index) {
                      final track = _searchTracks[index];
                      final isFav = _favorites.any((t) => t['id'] == track['id']);
                      return ListTile(
                        title: Text(track['title'] ?? 'Без названия'),
                        subtitle: Text(track['user']['name'] ?? 'Неизвестный'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
                              onPressed: () => _toggleFavorite(track),
                            ),
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => _playTrack(track),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('Избранное ❤️')),
      body: _favorites.isEmpty
          ? const Center(child: Text('Пока пусто. Лайкай треки в поиске!'))
          : ListView.builder(
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                final track = _favorites[index];
                return ListTile(
                  title: Text(track['title'] ?? 'Без названия'),
                  subtitle: Text(track['user']['name'] ?? 'Неизвестный'),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playTrack(track),
                  ),
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
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Твой персональный плейлист', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                      final track = _favorites[index];
                      return ListTile(
                        title: Text(track['title'] ?? 'Без названия'),
                        subtitle: Text(track['user']['name'] ?? 'Неизвестный'),
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
