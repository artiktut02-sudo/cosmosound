import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const CosmoSoundApp());

class CosmoSoundApp extends StatelessWidget {
  const CosmoSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CosmoSound',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const MainScreen(),
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

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
        setState(() {}); 
      }
    });
  }

  // Загружаем треки из открытого источника (SoundHelix)
  Future<void> _loadTracks() async {
    setState(() => _isLoading = true);
    // Это список проверенных бесплатных треков, которые точно играют
    final List<Map<String, String>> freeTracks = [
      {'title': 'SoundHelix 1', 'artist': 'Free Music', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'},
      {'title': 'SoundHelix 2', 'artist': 'Free Music', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'},
      {'title': 'SoundHelix 3', 'artist': 'Free Music', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3'},
      {'title': 'SoundHelix 4', 'artist': 'Free Music', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3'},
      {'title': 'SoundHelix 5', 'artist': 'Free Music', 'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3'},
    ];

    setState(() {
      _allTracks.clear();
      _allTracks.addAll(freeTracks);
      _isLoading = false;
    });
  }

  void _toggleFavorite(dynamic track) {
    setState(() {
      if (_favorites.any((t) => t['title'] == track['title'])) {
        _favorites.removeWhere((t) => t['title'] == track['title']);
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
      await _player.setUrl(track['url']);
      _player.play();
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
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.music_note, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text('CosmoSound', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
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
        ],
      ),
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
          : ListView.builder(
              itemCount: _allTracks.length,
              itemBuilder: (context, index) {
                final track = _allTracks[index];
                final isFav = _favorites.any((t) => t['title'] == track['title']);
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
