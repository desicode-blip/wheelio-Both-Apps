import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

void main() {
  for(final allowed in [false,true]) {
    testWidgets('AI permission returns only the explicit $allowed choice', (tester) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(home: Builder(builder:(context)=>TextButton(
        onPressed:() async {result=await requestAiPhotoConsent(context);}, child:const Text('Check'),
      ))));
      await tester.tap(find.text('Check'));await tester.pumpAndSettle();
      expect(result,isNull);
      expect(find.text('Allow Google AI photo check?'),findsOneWidget);
      expect(find.textContaining('Google Vertex AI (Gemini)'),findsOneWidget);
      await tester.ensureVisible(find.text(allowed?'Allow AI check':'Continue without AI'));
      expect(find.text(allowed?'Allow AI check':'Continue without AI').hitTestable(),findsOneWidget);
      await tester.tap(find.text(allowed?'Allow AI check':'Continue without AI'));await tester.pumpAndSettle();
      expect(result,allowed);
    });
  }
}
