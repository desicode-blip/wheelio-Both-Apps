import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/spoken_answer.dart';

void main() {
  test(
    'spoken choices support all app languages and reject ambiguous responses',
    () {
      expect(spokenAnswer('At home.', ['At the vehicle', 'At home']), 1);
      expect(spokenAnswer('one', ['Pour water', 'Wipe with dry cloth']), 0);
      expect(spokenAnswer('दूसरा', ['पानी डालें', 'सूखे कपड़े से पोंछें']), 1);
      expect(spokenAnswer('రెండవ', ['అవును', 'లేదు, నీళ్ళు మాత్రమే']), 1);
      expect(spokenAnswer('at', ['At the vehicle', 'At home']), isNull);
      expect(spokenAnswer('both', ['Yes', 'No, water only']), isNull);
      expect(spokenAnswer('', ['Yes', 'No']), isNull);
    },
  );
}
