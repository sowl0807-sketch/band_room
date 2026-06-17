import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/room_page.dart';
import 'pages/schedule_page.dart';
import 'pages/setlist_page.dart';

void main() async {
  // アプリケーション実行前の初期化処理
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BandRoomApp());
}

/// アプリケーションのルートウィジェット
/// 全体のテーマ設定と、認証状態に基づく初期画面のルーティングを管理します。
class BandRoomApp extends StatelessWidget {
  const BandRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BAND ROOM',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        useMaterial3: true,
      ),
      // ユーザーの認証状態を監視し、ログイン済みならメイン画面、未ログインならログイン画面へ遷移
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const MainTabScreen();
          }
          return const LoginPage();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// アプリケーションのメイン画面
/// 上部タブによる画面切り替えと、ログアウト機能を提供します。
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentTabIndex = 0;

  // タブで切り替える各画面のリスト
  final List<Widget> _pages = [
    const SetlistPage(),
    const RoomPage(),
    const SchedulePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // カスタムタブバーエリア
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _buildTabButton('SETLIST', 0)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTabButton('ROOM', 1)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTabButton('SCHEDULE', 2)),
                ],
              ),
            ),

            // メインコンテンツ表示エリア
            Expanded(
              child: _pages[_currentTabIndex],
            ),

            // ログアウトボタン
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
              child: TextButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout, color: Colors.grey, size: 18),
                label: const Text(
                  'ログアウト',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// カスタムタブボタンを生成するヘルパーメソッド
  Widget _buildTabButton(String title, int index) {
    final bool isSelected = _currentTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: Container(
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  )
                ],
          border: Border.all(
            color: isSelected
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.green[800] : Colors.grey[600],
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
