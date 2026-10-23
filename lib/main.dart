import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const CosmoSoundApp());

class CosmoSoundApp extends StatelessWidget {
  const CosmoSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CosmoSound',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

// Главный экран с нижней навигацией
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // Общее состояние для всех вкладок
  final List<dynamic> _searchTracks = [];
  final List<dynamic> _favorites = [];
  bool _isLoading = false;
  final AudioPlayer _player = AudioPlayer();

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

  @override
  Widget build(BuildContext context) {
    // Экраны для вкладок
    final List<Widget> _pages = [
      _buildSearchPage(),
      _buildFavoritesPage(),
      _buildUniversePage(),
    ];

    return Scaffold(
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

  // Вкладка "Поиск"
  Widget _buildSearchPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('CosmoSound 🚀')),
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
                ? const Center(child: Text('Введите запрос'))
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

  // Вкладка "Избранное"
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

  // Вкладка "Моя вселенная"
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
