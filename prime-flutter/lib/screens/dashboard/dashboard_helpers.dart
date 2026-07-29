/// Shared calendar + date helpers for dashboard modules.
library;

const dashboardMonthNames = [
  '',
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const dashboardWeekdayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const dashboardChallengeDays = 30;

String dashboardTodayLabel() {
  const weekdays = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];
  const months = [
    '',
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final now = DateTime.now();
  return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month]}';
}

String dashboardDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String dashboardCalendarDateLabel(DateTime date) {
  return '${date.day} ${dashboardMonthNames[date.month].toLowerCase()} ${date.year}';
}

DateTime dashboardTodayDateOnly() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
