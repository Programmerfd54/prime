abstract final class ProgressLabels {
  static String search({required int found, required int needed}) =>
      'Поиск · $found из $needed участников';

  static String confirm({required int confirmed, required int total}) =>
      'Подтверждение · $confirmed из $total';

  static String pact({required int accepted, required int total}) =>
      'Договор · $accepted из $total';

  static String report({required int ready, required int total}) =>
      'Отчёты сегодня · $ready из $total';

  static String cycle({required int day}) => 'День цикла · $day из 30';
}
