import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SetlistPage extends StatefulWidget {
  const SetlistPage({super.key});

  @override
  State<SetlistPage> createState() => _SetlistPageState();
}

class _SetlistPageState extends State<SetlistPage> {
  bool _isLoading = false;
  String _loadingMessage = "";

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;

  bool _isContinuousPlayEnabled = false;
  List<String> _currentPlaylistUrls = [];

  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListeners();
  }

  /// AudioPlayerのイベントリスナーを設定
  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        _handlePlaybackCompletion();
      }
    });
  }

  /// 連続再生のロジック。現在の曲のインデックスを探して、次の曲があれば再生する処理(非同期処理の連続で苦労した部分)
  void _handlePlaybackCompletion() {
    if (_isContinuousPlayEnabled && _currentlyPlayingUrl != null) {
      int currentIndex = _currentPlaylistUrls.indexOf(_currentlyPlayingUrl!);

      if (currentIndex >= 0 && currentIndex < _currentPlaylistUrls.length - 1) {
        String nextUrl = _currentPlaylistUrls[currentIndex + 1];
        _playAudio(nextUrl);
        return;
      }
    }

    setState(() {
      _isPlaying = false;
      _currentlyPlayingUrl = null;
    });
  }

  /// 指定したURLの音源を再生する
  Future<void> _playAudio(String url) async {
    await _audioPlayer.play(UrlSource(url));
    setState(() {
      _currentlyPlayingUrl = url;
      _isPlaying = true;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Durationを mm:ss (または hh:mm:ss) 形式の文字列に変換
  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  /// 音声ファイルのアップロード処理。FilePickerで取得 -> 長さ解析 -> Storageへアップロード -> Firestoreへデータ保存という流れ。
  Future<void> _pickAudioFile() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = "ファイルを選択中...";
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final String fileName = result.files.single.name;
        final Uint8List fileBytes = result.files.single.bytes!;

        setState(() => _loadingMessage = "曲の長さを解析中...");

        final tempPlayer = AudioPlayer();
        await tempPlayer.setSource(BytesSource(fileBytes));
        await Future.delayed(const Duration(milliseconds: 500));
        Duration? songDuration = await tempPlayer.getDuration();
        await tempPlayer.dispose();

        songDuration ??= const Duration(seconds: 0);

        setState(() => _loadingMessage = "クラウドにアップロード中...\n（グループ全員に共有されます）");

        final storageRef = FirebaseStorage.instance.ref().child(
            'setlists/${DateTime.now().millisecondsSinceEpoch}_$fileName');

        UploadTask uploadTask = storageRef.putData(
          fileBytes,
          SettableMetadata(contentType: 'audio/mpeg'),
        );

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        setState(() => _loadingMessage = "セットリストに登録中...");

        await FirebaseFirestore.instance.collection('setlists').add({
          'title': fileName,
          'url': downloadUrl,
          'duration_seconds': songDuration.inSeconds,
          'created_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('「$fileName」を共有セットリストに追加しました！')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('エラーが発生しました: $e\nFirebaseコンソールのStorage設定を確認してください。')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = "";
        });
      }
    }
  }

  /// 再生・一時停止のトグル処理
  Future<void> _togglePlay(String url) async {
    if (_currentlyPlayingUrl == url && _isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _playAudio(url);
    }
  }

  /// 曲順を上に移動 (前のドキュメントと created_at を入れ替える)
  Future<void> _moveUp(int index, List<QueryDocumentSnapshot> docs) async {
    if (index <= 0) return;
    try {
      final currentDoc = docs[index];
      final prevDoc = docs[index - 1];

      final currentData = currentDoc.data() as Map<String, dynamic>;
      final prevData = prevDoc.data() as Map<String, dynamic>;

      final currentCreatedAt = currentData['created_at'];
      final prevCreatedAt = prevData['created_at'];

      if (currentCreatedAt == null || prevCreatedAt == null) return;

      final batch = FirebaseFirestore.instance.batch();
      batch.update(currentDoc.reference, {'created_at': prevCreatedAt});
      batch.update(prevDoc.reference, {'created_at': currentCreatedAt});
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('並び替えに失敗しました: $e')),
        );
      }
    }
  }

  /// 曲順を下に移動 (次のドキュメントと created_at を入れ替える)
  Future<void> _moveDown(int index, List<QueryDocumentSnapshot> docs) async {
    if (index >= docs.length - 1) return;
    try {
      final currentDoc = docs[index];
      final nextDoc = docs[index + 1];

      final currentData = currentDoc.data() as Map<String, dynamic>;
      final nextData = nextDoc.data() as Map<String, dynamic>;

      final currentCreatedAt = currentData['created_at'];
      final nextCreatedAt = nextData['created_at'];

      if (currentCreatedAt == null || nextCreatedAt == null) return;

      final batch = FirebaseFirestore.instance.batch();
      batch.update(currentDoc.reference, {'created_at': nextCreatedAt});
      batch.update(nextDoc.reference, {'created_at': currentCreatedAt});
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('並び替えに失敗しました: $e')),
        );
      }
    }
  }

  /// 指定した曲の削除処理
  Future<void> _deleteSong(String docId, String url) async {
    try {
      if (_currentlyPlayingUrl == url) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _currentlyPlayingUrl = null;
        });
      }
      await FirebaseFirestore.instance
          .collection('setlists')
          .doc(docId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('削除エラー: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title:
            const Text('セットリスト', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                setState(() {
                  _isContinuousPlayEnabled = !_isContinuousPlayEnabled;
                });

                if (_isContinuousPlayEnabled &&
                    _currentPlaylistUrls.isNotEmpty) {
                  if (!_isPlaying || _currentlyPlayingUrl == null) {
                    await _playAudio(_currentPlaylistUrls.first);
                  }
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _isContinuousPlayEnabled ? Colors.blue : Colors.grey[200],
                ),
                child: Icon(
                  Icons.repeat,
                  size: 22,
                  color: _isContinuousPlayEnabled
                      ? Colors.white
                      : Colors.grey[600],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _isLoading
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      size: 28, color: Colors.blue),
                  onPressed: _pickAudioFile,
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('setlists')
            .orderBy('created_at', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (_isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_loadingMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text('データの同期に失敗しました。'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '楽曲が登録されていません。\n右上の「+」から追加してください。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          _currentPlaylistUrls = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['url'] as String? ?? '';
          }).toList();

          int totalSeconds = 0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalSeconds += (data['duration_seconds'] as int?) ?? 0;
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    String title = data['title'] ?? '不明な曲';
                    String url = data['url'] ?? '';
                    int durationSec = data['duration_seconds'] ?? 0;
                    Duration duration = Duration(seconds: durationSec);

                    bool isThisPlaying =
                        (_currentlyPlayingUrl == url && _isPlaying);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isThisPlaying
                              ? Colors.blue.withOpacity(0.5)
                              : Colors.grey[200]!,
                          width: isThisPlaying ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        leading: CircleAvatar(
                          backgroundColor:
                              isThisPlaying ? Colors.blue : Colors.grey[400],
                          child: isThisPlaying
                              ? const Icon(Icons.music_note,
                                  color: Colors.white)
                              : const Icon(Icons.music_note_outlined,
                                  color: Colors.white),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isThisPlaying
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isThisPlaying
                                ? Colors.blue[800]
                                : Colors.black87,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Layout Overflow の修正箇所
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black54),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                isThisPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                color: isThisPlaying
                                    ? Colors.blue
                                    : Colors.grey[400],
                                size: 32,
                              ),
                              onPressed: () => _togglePlay(url),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: index == 0
                                      ? null
                                      : () => _moveUp(index, docs),
                                  child: Icon(
                                    Icons.arrow_drop_up,
                                    size: 24,
                                    color: index == 0
                                        ? Colors.grey[300]
                                        : Colors.blue,
                                  ),
                                ),
                                InkWell(
                                  onTap: index == docs.length - 1
                                      ? null
                                      : () => _moveDown(index, docs),
                                  child: Icon(
                                    Icons.arrow_drop_down,
                                    size: 24,
                                    color: index == docs.length - 1
                                        ? Colors.grey[300]
                                        : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 24),
                              onPressed: () => _deleteSong(doc.id, url),
                            ),
                          ],
                        ),
                        onTap: () => _togglePlay(url),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '総再生時間',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      Text(
                        _formatDuration(Duration(seconds: totalSeconds)),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
