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
      home: const MusicHomePage(),
    );
  }
}

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  final AudioPlayer _player = AudioPlayer();
  List<dynamic> _tracks = [];
  bool _isLoading = false;

  Future<void> _searchTracks(String query) async {
    setState(() => _isLoading = true);
    final String apiHost = 'https://discoveryprovider.audius.co';
    final url = Uri.parse('$apiHost/v1/tracks/search?query=$query&app_name=CosmoSound');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tracks = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Ошибка: $e');
    }
  }

  Future<void> _playTrack(String trackId) async {
    try {
      final String apiHost = 'https://discoveryprovider.audius.co';
      final url = Uri.parse('$apiHost/v1/tracks/$trackId/stream?app_name=CosmoSound');
      await _player.setUrl(url.toString());
      _player.play();
    } catch (e) {
      debugPrint('Ошибка воспроизведения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CosmoSound 🚀')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Найти космический трек...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: _searchTracks,
            ),
          ),
          if (_isLoading) const CircularProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final track = _tracks[index];
                return ListTile(
                  title: Text(track['title'] ?? 'Без названия'),
                  subtitle: Text(track['user']['name'] ?? 'Неизвестный'),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => _playTrack(track['id']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
