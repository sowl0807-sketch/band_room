import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestoreを使うために追加

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteCodeController =
      TextEditingController(); // 【追加】招待コード用のコントローラー

  Future<void> _signUp() async {
    try {
      // アカウント作成
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 作成したアカウントに「名前」を登録する
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      // 招待コードの判定。空欄なら「ランダムなグループ専用ID」を自動生成する
      String inviteCode = _inviteCodeController.text.trim();
      String myGroupId = inviteCode.isEmpty
          ? FirebaseFirestore.instance.collection('groups').doc().id // 自動生成！
          : inviteCode;

      // Firestoreのusersコレクションに保存。ここでgroupIdを持たせることでチャット等の共有
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'groupId': myGroupId,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規アカウント登録')),
      body: SingleChildScrollView(
        // キーボードが出た時の画面崩れを防ぐために包んでいます
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '表示名（バンド内での名前）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // 【追加】招待コードの入力欄
              TextField(
                controller: _inviteCodeController,
                decoration: const InputDecoration(
                  labelText: '招待コード（既存のバンドに入る場合のみ入力）',
                  hintText: '空欄のままだと、新しくあなた主宰のバンドを作ります',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: 'メールアドレス', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'パスワード', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _signUp,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('アカウントを作成する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
