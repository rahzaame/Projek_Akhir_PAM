
import 'package:flutter_test/flutter_test.dart';
import 'package:projek_akhir_pam/main.dart';

void main() {
  testWidgets('SafarMate menampilkan halaman login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SafarMateApp());

    expect(find.text('SafarMate'), findsOneWidget);
    expect(find.text('Halaman Login SafarMate'), findsOneWidget);
  });
}
