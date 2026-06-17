import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 入力された文字を管理するコントローラー
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';

  // ログイン処理
  Future<void> _login() async {
    try {
      // signInWithEmailAndPassword がログイン用の命令です
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // 成功した場合
      setState(() {
        _errorMessage = 'ログインに成功しました！';
      });
    } on FirebaseAuthException catch (e) {
      // エラーが起きた場合（パスワード間違いなど）
      setState(() {
        _errorMessage = 'ログインに失敗しました: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン'),
      ),
      body: Center(
        // // 画面中央に配置。キーボード表示時のエラー（Overflow）対策でSingleChildScrollViewを使用
        child: SingleChildScrollView(
          // スマホでキーボードが出たときの画面割れ（溢れ）を防ぐ
          child: Container(
            padding: const EdgeInsets.all(24.0),
            // Webブラウザで見た時に横に広がりすぎないよう、最大幅を制限（ChatGPTのアドバイスを参考）
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // 💡 4. 中のボタンなどを横いっぱいに綺麗に広げます
              children: [
                // メールアドレス入力欄
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    border: OutlineInputBorder(), // 💡 枠線を付けるとWebでもすっきり見やすくなります
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // パスワード入力欄
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'パスワード',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true, // 文字を隠す設定
                ),
                const SizedBox(height: 24),

                // ログインボタン
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16), // ボタンに少し厚みを出して押しやすく
                  ),
                  child: const Text('ログイン'),
                ),
                const SizedBox(height: 16),

                // 結果・エラーメッセージ表示
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SignupPage()),
                    );
                  },
                  child: const Text('アカウントをお持ちでない方はこちら（新規登録）'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
