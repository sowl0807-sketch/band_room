import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();

  // データをFirestoreに送信する関数
  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('messages').add({
      'text': _controller.text,
      'sender': 'kimura',
      'createdAt': Timestamp.now(), // 送信時間を記録
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('リアルタイムチャット画面')),
      body: Column(
        children: [
          // ⭐️ ここを書き換え！Firestoreからデータをリアルタイムに読み込む魔法の部品
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // messagesコレクションを、送信時間が新しい順（降順）に並び替えて監視する
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // 読み込み中の待ち時間
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // データが何も無いとき
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('まだメッセージはありません。'));
                }

                // 届いたデータの塊をリストに変換
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // チャットのように下から上へ並べる
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['text'] ?? ''),
                      subtitle: Text(data['sender'] ?? '不明なユーザー'),
                    );
                  },
                );
              },
            ),
          ),

          // 下半分の入力エリア（ここはそのまま）
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'メッセージを入力...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
