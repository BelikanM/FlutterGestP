// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Basic test setup', () {
    // Test de base pour vérifier que les tests fonctionnent
    expect(1 + 1, equals(2));
  });
  
  test('String operations', () {
    expect('Hello World'.contains('World'), isTrue);
    expect('test@example.com'.contains('@'), isTrue);
  });
}
