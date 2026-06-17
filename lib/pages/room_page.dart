import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  final TextEditingController _chatController = TextEditingController();

  String? _groupId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserGroup();
  }

  @override
  void dispose() {
    // メモリリーク対策として、画面を閉じるときにコントローラーを破棄（Zennの記事を参考）
    _chatController.dispose();
    super.dispose();
  }

  /// ログイン中のユーザー情報から所属しているグループIDを取得する
  Future<void> _fetchUserGroup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            _groupId = doc.data()?['groupId'];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      // 必要に応じてログ出力等を行う
      debugPrint('グループ情報の取得に失敗しました: $e');
    }

    // データ未作成時のフォールバック処理 TODO: 万が一グループIDが取得できなかった場合のエラーハンドリング。一旦テスト用のIDを入れているが、将来的にはエラー画面を出したい。
    if (mounted) {
      setState(() {
        _groupId = 'my_band_01';
        _isLoading = false;
      });
    }
  }

  /// 入力されたメッセージをFirestoreに送信する
  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _groupId == null) return;

    final user = FirebaseAuth.instance.currentUser;
    final String senderName = user?.displayName ?? user?.email ?? '不明なメンバー';

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(_groupId)
          .collection('messages')
          .add({
        'text': text,
        'sender': senderName,
        // デバイスの時刻ズレを防ぐため、サーバー側の正確な時間を記録
        'createdAt': FieldValue.serverTimestamp(),
      });

      _chatController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('メッセージの送信に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '【ROOM】メンバーチャット',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),

          // 所属グループの招待コード表示エリア
          SelectableText(
            'このバンドの招待コード:\n$_groupId',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

          // チャット履歴の表示エリア
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(8),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(_groupId)
                    .collection('messages')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('メッセージの読み込みに失敗しました。',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'まだメッセージはありません。\n最初のメッセージを送ってみよう！',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final messageText = data['text'] ?? '';
                      final sender = data['sender'] ?? '不明';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          '・ [$sender] $messageText',
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // メッセージ入力・送信エリア
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'メッセージを入力...',
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                color: Colors.green[700],
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
