import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:band_room/pages/login_page.dart'; // ※ご自身のプロジェクトパスに合わせて調整してください

void main() {
  testWidgets('ログイン画面にメールとパスワードの入力欄が表示されているかテスト', (WidgetTester tester) async {
    // ログインページをテスト用にビルド（MaterialAppで囲むのがコツです）
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    // 1. ラベル名で入力欄が見つかるか確認
    expect(find.text('メールアドレス'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);

    // 2. ログインボタンが表示されているか確認
    expect(find.widgetWithText(ElevatedButton, 'ログイン'), findsOneWidget);
  });
}
