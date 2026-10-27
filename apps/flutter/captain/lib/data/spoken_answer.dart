/// Speech can select only an unambiguous visible option; it cannot pass a quiz.
int? spokenAnswer(String words, List<String> options) {
  String normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s.,!?।…]+'), '');
  final text = normalized(words);
  if (text.isEmpty) return null;
  const first = {
    '1',
    'one',
    'first',
    'optionone',
    'option1',
    'पहला',
    'पहली',
    'एक',
    'మొదటి',
    'ఒకటి',
  };
  const second = {
    '2',
    'two',
    'second',
    'optiontwo',
    'option2',
    'दूसरा',
    'दूसरी',
    'दो',
    'రెండవ',
    'రెండు',
  };
  if (first.contains(text)) return 0;
  if (second.contains(text)) return 1;
  final matches = <int>[];
  for (var i = 0; i < options.length; i++) {
    final option = normalized(options[i]);
    if (option == text ||
        text.contains(option) ||
        (text.length >= 2 && option.startsWith(text))) {
      matches.add(i);
    }
  }
  return matches.length == 1 ? matches.single : null;
}
