import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class MusicPlayerScreen extends StatefulWidget {
  @override
  _MusicPlayerScreenState createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _currentFilePath;
  String? _currentFileName;
  List<Map<String, String>> _musicList = [];
  bool _isLoading = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
    _checkPermissionAndLoadMusic();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });
  }

  Future<void> _checkPermissionAndLoadMusic() async {
    // İzinleri kontrol et
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
      });
      _loadDeviceMusic();
    } else {
      _showError('Müziklere erişim izni verilmedi. Lütfen ayarlardan izin verin.');
    }
  }

  Future<void> _loadDeviceMusic() async {
    setState(() {
      _isLoading = true;
      _musicList.clear();
    });

    try {
      // Önce çevrimiçi örnek müzikleri ekle
      _musicList.add({
        'name': 'Örnek Müzik 1',
        'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        'type': 'online'
      });

      _musicList.add({
        'name': 'Örnek Müzik 2',
        'url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        'type': 'online'
      });

      // Cihazdaki müzikleri tara
      await _scanForMusicFiles();
      
    } catch (e) {
      print('Müzik yükleme hatası: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanForMusicFiles() async {
    try {
      // Android'de yaygın müzik klasörleri
      List<String> commonPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/',
      ];

      for (String path in commonPaths) {
        await _scanDirectory(Directory(path));
      }

      // External storage directory'yi de tara
      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        await _scanDirectory(externalDir);
      }

      // Downloads directory'yi tara
      Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        await _scanDirectory(downloadsDir);
      }

    } catch (e) {
      print('Müzik tarama hatası: $e');
    }
  }

  Future<void> _scanDirectory(Directory directory) async {
    try {
      if (await directory.exists()) {
        List<FileSystemEntity> entities = await directory.list().toList();
        
        for (var entity in entities) {
          if (entity is File) {
            String path = entity.path.toLowerCase();
            if (_isMusicFile(path)) {
              _addMusicToLocalList(entity);
            }
          } else if (entity is Directory) {
            // Alt dizinleri de tara (sınırlı sayıda)
            await _scanDirectory(entity);
          }
          
          // Performans için sınır
          if (_musicList.length > 100) break;
        }
      }
    } catch (e) {
      print('${directory.path} taranırken hata: $e');
    }
  }

  bool _isMusicFile(String path) {
    return path.endsWith('.mp3') || 
           path.endsWith('.m4a') || 
           path.endsWith('.wav') || 
           path.endsWith('.aac') ||
           path.endsWith('.ogg');
  }

  void _addMusicToLocalList(File file) {
    String fileName = file.path.split('/').last;
    
    // Aynı müziği tekrar eklemeyi önle ve dosya boyutu kontrolü
    if (!_musicList.any((music) => music['path'] == file.path)) {
      _musicList.add({
        'name': fileName,
        'path': file.path,
        'type': 'local'
      });
    }
  }

  void _playMusic(int index) async {
    try {
      var music = _musicList[index];
      _currentFilePath = music['type'] == 'online' ? music['url'] : music['path'];
      _currentFileName = music['name'];

      await _audioPlayer.stop();
      
      if (music['type'] == 'online') {
        await _audioPlayer.play(UrlSource(_currentFilePath!));
      } else {
        await _audioPlayer.play(DeviceFileSource(_currentFilePath!));
      }
      
      setState(() {});
    } catch (e) {
      _showError('Müzik çalınırken hata: $e');
    }
  }

  void _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_currentFilePath != null) {
          if (_currentFilePath!.startsWith('http')) {
            await _audioPlayer.play(UrlSource(_currentFilePath!));
          } else {
            await _audioPlayer.play(DeviceFileSource(_currentFilePath!));
          }
        } else if (_musicList.isNotEmpty) {
          // Eğer hiç müzik seçilmemişse ilk müziği çal
          _playMusic(0);
        } else {
          _showError('Lütfen önce bir müzik seçin');
        }
      }
    } catch (e) {
      _showError('Oynatma hatası: $e');
    }
  }

  void _stop() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    } catch (e) {
      _showError('Durdurma hatası: $e');
    }
  }

  void _nextMusic() {
    if (_musicList.isEmpty) return;
    
    int currentIndex = _musicList.indexWhere((music) => 
        music['type'] == 'online' ? music['url'] == _currentFilePath : music['path'] == _currentFilePath);
    
    if (currentIndex != -1) {
      int nextIndex = (currentIndex + 1) % _musicList.length;
      _playMusic(nextIndex);
    } else if (_musicList.isNotEmpty) {
      _playMusic(0);
    }
  }

  void _previousMusic() {
    if (_musicList.isEmpty) return;
    
    int currentIndex = _musicList.indexWhere((music) => 
        music['type'] == 'online' ? music['url'] == _currentFilePath : music['path'] == _currentFilePath);
    
    if (currentIndex != -1) {
      int prevIndex = (currentIndex - 1) % _musicList.length;
      if (prevIndex < 0) prevIndex = _musicList.length - 1;
      _playMusic(prevIndex);
    } else if (_musicList.isNotEmpty) {
      _playMusic(0);
    }
  }

  void _refreshMusic() {
    _loadDeviceMusic();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int localMusicCount = _musicList.where((music) => music['type'] == 'local').length;
    int onlineMusicCount = _musicList.where((music) => music['type'] == 'online').length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Başlık Kartı
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.music_note, size: 40, color: Colors.blue),
                      if (_hasPermission)
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: _refreshMusic,
                          tooltip: 'Müzikleri Yenile',
                        ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'M4A, MP3, WAV Player',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text('Cihazınızdaki müzikleri otomatik tarar'),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // İstatistikler
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(
                          '$localMusicCount',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        Text('Yerel Müzik', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text(
                          '$onlineMusicCount',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        Text('Çevrimiçi', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Yenile Butonu
          ElevatedButton.icon(
            onPressed: _refreshMusic,
            icon: Icon(Icons.search),
            label: Text('Müzikleri Tara ve Yenile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Cihazınızdaki M4A, MP3 dosyalarını otomatik bulur',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),

          // Müzik Listesi
          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Müzikler taranıyor...'),
                    SizedBox(height: 10),
                    Text(
                      'Bu işlem cihazınızdaki dosya sayısına göre\nbirkaç saniye sürebilir',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else if (_musicList.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_off, size: 60, color: Colors.grey[300]),
                    SizedBox(height: 20),
                    Text(
                      'Henüz müzik bulunamadı\n\n"Müzikleri Tara" butonuna tıklayarak\ncihazınızdaki müzik dosyalarını bulun',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 30),
                    if (!_hasPermission)
                      ElevatedButton(
                        onPressed: _checkPermissionAndLoadMusic,
                        child: Text('İzin Ver ve Tara'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _musicList.length,
                itemBuilder: (context, index) {
                  var music = _musicList[index];
                  bool isCurrent = music['type'] == 'online' 
                      ? music['url'] == _currentFilePath
                      : music['path'] == _currentFilePath;
                  
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    color: isCurrent ? Colors.blue[50] : null,
                    child: ListTile(
                      leading: Icon(
                        music['type'] == 'online' ? Icons.cloud : Icons.music_note,
                        color: isCurrent ? Colors.blue : Colors.grey,
                      ),
                      title: Text(
                        music['name']!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        music['type'] == 'online' ? 'Çevrimiçi Müzik' : 'Cihazda Kayıtlı',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: isCurrent && _isPlaying
                          ? Icon(Icons.equalizer, color: Colors.blue)
                          : null,
                      onTap: () => _playMusic(index),
                    ),
                  );
                },
              ),
            ),

          // Şu an çalan ve kontroller
          if (_currentFileName != null) ...[
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Şu an çalınıyor:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(
                      _currentFileName!,
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Progress Bar
            Slider(
              min: 0,
              max: _duration.inSeconds.toDouble(),
              value: _position.inSeconds.toDouble(),
              onChanged: (value) async {
                try {
                  await _audioPlayer.seek(Duration(seconds: value.toInt()));
                } catch (e) {
                  _showError('Seek hatası: $e');
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatTime(_position)),
                  Text(_formatTime(_duration)),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Kontrol Butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 40),
                  onPressed: _previousMusic,
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 60,
                    color: Colors.blue,
                  ),
                  onPressed: _playPause,
                ),
                IconButton(
                  icon: Icon(Icons.stop_circle, size: 40),
                  onPressed: _stop,
                ),
                IconButton(
                  icon: Icon(Icons.skip_next, size: 40),
                  onPressed: _nextMusic,
                ),
              ],
            ),
            SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}