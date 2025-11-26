import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  int _currentVideoIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = false;

  final List<Map<String, String>> _videoList = [
    {
      'name': 'Örnek Video 1',
      'url': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'
    },
    {
      'name': 'Örnek Video 2',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
    },
    {
      'name': 'Örnek Video 3',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideo(0);
  }

  void _initializeVideo(int index) async {
    setState(() {
      _isLoading = true;
      _currentVideoIndex = index;
    });

    try {
      // Eski controller'ı temizle
      if (_videoPlayerController != null) {
        await _videoPlayerController.dispose();
      }

      // Yeni controller oluştur
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_videoList[index]['url']!),
      );

      await _videoPlayerController.initialize();
      
      _videoPlayerController.addListener(() {
        setState(() {
          _isPlaying = _videoPlayerController.value.isPlaying;
        });
      });

      // Otomatik oynat
      await _videoPlayerController.play();

    } catch (e) {
      _showError('Video yüklenirken hata: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _playPause() {
    if (_isPlaying) {
      _videoPlayerController.pause();
    } else {
      _videoPlayerController.play();
    }
  }

  void _playVideo(int index) {
    _initializeVideo(index);
  }

  void _nextVideo() {
    int nextIndex = (_currentVideoIndex + 1) % _videoList.length;
    _playVideo(nextIndex);
  }

  void _previousVideo() {
    int prevIndex = (_currentVideoIndex - 1) % _videoList.length;
    if (prevIndex < 0) prevIndex = _videoList.length - 1;
    _playVideo(prevIndex);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  Icon(Icons.video_library, size: 40, color: Colors.red),
                  SizedBox(height: 10),
                  Text(
                    'MP4 Video Player',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text('Çevrimiçi örnek videolar'),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Video Listesi
          Container(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _videoList.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _playVideo(index),
                  child: Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _currentVideoIndex == index ? Colors.red[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _currentVideoIndex == index ? Colors.red : Colors.grey,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow, 
                          color: _currentVideoIndex == index ? Colors.red : Colors.grey,
                        ),
                        SizedBox(height: 5),
                        Text(
                          _videoList[index]['name']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentVideoIndex == index 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),

          // Video Player
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('Video yükleniyor...'),
                      ],
                    ),
                  )
                : _videoPlayerController.value.isInitialized
                    ? Column(
                        children: [
                          AspectRatio(
                            aspectRatio: _videoPlayerController.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                VideoPlayer(_videoPlayerController),
                                VideoProgressIndicator(
                                  _videoPlayerController,
                                  allowScrubbing: true,
                                  colors: VideoProgressColors(
                                    playedColor: Colors.red,
                                    bufferedColor: Colors.grey,
                                    backgroundColor: Colors.grey[300]!,
                                  ),
                                ),
                                Positioned(
                                  bottom: 10,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.skip_previous,
                                            color: Colors.white,
                                          ),
                                          onPressed: _previousVideo,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _isPlaying ? Icons.pause : Icons.play_arrow,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                          onPressed: _playPause,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.skip_next,
                                            color: Colors.white,
                                          ),
                                          onPressed: _nextVideo,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          // Ek Kontroller
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.volume_up),
                                onPressed: () {
                                  // Ses kontrolü - basit implementasyon
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.fullscreen),
                                onPressed: () {
                                  // Tam ekran - basit implementasyon
                                },
                              ),
                            ],
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library, size: 60, color: Colors.grey[300]),
                            SizedBox(height: 20),
                            Text(
                              'Video yüklenemedi\n\nLütfen internet bağlantınızı kontrol edin',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
          ),

          // Video Bilgisi
          if (_videoList.isNotEmpty && !_isLoading) ...[
            SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Şu an oynatılıyor: ${_videoList[_currentVideoIndex]['name']!}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _isPlaying ? 'Oynatılıyor' : 'Duraklatıldı',
                          style: TextStyle(
                            color: _isPlaying ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}