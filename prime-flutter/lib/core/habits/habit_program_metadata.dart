import '../../l10n/copy.dart';
import '../../models/skill.dart';

/// Static program facts from product copy — no invented live stats.
class HabitProgramMeta {
  const HabitProgramMeta({
    required this.dailyAction,
    required this.outcome,
    required this.difficulty,
    required this.timeOfDay,
    required this.durationLabel,
    required this.reportFormat,
    required this.skipPolicy,
    required this.teamRole,
    required this.sampleDay,
    required this.faq,
  });

  final String dailyAction;
  final String outcome;
  final String difficulty;
  final String timeOfDay;
  final String durationLabel;
  final String reportFormat;
  final String skipPolicy;
  final String teamRole;
  final List<String> sampleDay;
  final List<HabitFaqItem> faq;
}

class HabitFaqItem {
  const HabitFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

abstract final class HabitProgramCatalog {
  static HabitProgramMeta metaFor(SkillModel skill) {
    return _byId[skill.id] ?? _defaultMeta(skill);
  }

  /// Lookup by skill id when a full [SkillModel] is not available.
  static HabitProgramMeta? metaForId(String? skillId) {
    if (skillId == null || skillId.isEmpty) return null;
    return _byId[skillId];
  }

  static HabitProgramMeta _defaultMeta(SkillModel skill) {
    final desc = skill.description.trim();
    return HabitProgramMeta(
      dailyAction: desc.isNotEmpty ? desc : 'Ежедневное действие по программе',
      outcome: 'Устойчивый ритм на ${AppCopy.cycleDays}',
      difficulty: 'Средняя',
      timeOfDay: 'Любое',
      durationLabel: '10–20 мин',
      reportFormat: 'Текст и при желании фото',
      skipPolicy:
          'Пропуск без отчёта не засчитывается. Честно напишите команде, если сорвались.',
      teamRole:
          'Команда из 6 поддерживает темп — без публичного рейтинга «худших».',
      sampleDay: const [
        '09:00 — короткое действие',
        '20:00 — отчёт в чате группы',
      ],
      faq: _commonFaq,
    );
  }

  static const _commonFaq = [
    HabitFaqItem(
      question: 'Можно ли начать не с понедельника?',
      answer:
          'Да. Цикл стартует после подтверждения всей команды, а не по календарю.',
    ),
    HabitFaqItem(
      question: 'Что если пропущу день?',
      answer:
          'Серия прервётся, но вы можете вернуться на следующий день. Команда увидит статус в отчётах.',
    ),
  ];

  static final _byId = <String, HabitProgramMeta>{
    'morning-focus': HabitProgramMeta(
      dailyAction:
          '15 минут без телефона: намерение дня + одно главное действие.',
      outcome: 'Спокойное, собранное начало дня',
      difficulty: 'Средняя',
      timeOfDay: 'Утро',
      durationLabel: '15 мин',
      reportFormat: 'Короткий текст: что сделали и как себя чувствуете',
      skipPolicy:
          'Если пропустили утро — отметьте «не готов» и напишите команде план на вечер.',
      teamRole: 'Команда делится утренними якорями — без соревнования «кто раньше».',
      sampleDay: const [
        '07:30 — 5 мин тишины, без экрана',
        '07:45 — записать главное намерение',
        '21:00 — отчёт в группе',
      ],
      faq: [
        ..._commonFaq,
        const HabitFaqItem(
          question: 'Нужен будильник в 5:00?',
          answer: 'Нет. Важна регулярность в вашем реальном утреннем окне.',
        ),
      ],
    ),
    'digital-detox': HabitProgramMeta(
      dailyAction:
          'Одно осознанное «окно без экрана» минимум 30 минут в выбранное время.',
      outcome: 'Меньше фонового скролла, больше фокуса',
      difficulty: 'Средняя',
      timeOfDay: 'День / вечер',
      durationLabel: '30+ мин',
      reportFormat: 'Что помогло удержаться и что было сложно',
      skipPolicy: 'Честный отчёт «не готов» лучше молчания.',
      teamRole: 'Участники делятся лайфхаками без осуждения.',
      sampleDay: const [
        '12:00 — обед без телефона',
        '20:30 — отчёт: сколько минут и что заметили',
      ],
      faq: _commonFaq,
    ),
    'one-chapter': HabitProgramMeta(
      dailyAction: 'Прочитать минимум одну главу (или 20 страниц).',
      outcome: 'Регулярное чтение без перегруза',
      difficulty: 'Лёгкая',
      timeOfDay: 'Вечер',
      durationLabel: '20–40 мин',
      reportFormat: 'Название книги + одна мысль из главы',
      skipPolicy: 'Можно сократить до 10 страниц — но отметить в отчёте.',
      teamRole: 'Обмен рекомендациями книг в чате.',
      sampleDay: const [
        '21:00 — одна глава',
        '21:30 — отчёт с цитатой или мыслью',
      ],
      faq: _commonFaq,
    ),
    'body-charge': HabitProgramMeta(
      dailyAction: '10–15 минут движения: зарядка, прогулка или растяжка.',
      outcome: 'Тело в тонусе без марафонов',
      difficulty: 'Средняя',
      timeOfDay: 'Утро / день',
      durationLabel: '10–15 мин',
      reportFormat: 'Тип активности + самочувствие',
      skipPolicy: 'Лёгкая прогулка считается, если нет сил на зарядку.',
      teamRole: 'Поддержка без сравнения «кто больше шагов».',
      sampleDay: const [
        '08:00 — 12 минут зарядки',
        '21:00 — отчёт',
      ],
      faq: _commonFaq,
    ),
    'evening-ritual': HabitProgramMeta(
      dailyAction:
          '20 минут вечернего ритуала: экран off, подготовка ко сну, рефлексия.',
      outcome: 'Мягкое завершение дня',
      difficulty: 'Лёгкая',
      timeOfDay: 'Вечер',
      durationLabel: '20 мин',
      reportFormat: 'Что помогло расслабиться',
      skipPolicy: 'Минимум 5 минут рефлексии, если день тяжёлый.',
      teamRole: 'Команда делится вечерними якорями.',
      sampleDay: const [
        '22:00 — телефон в другую комнату',
        '22:15 — три строки рефлексии',
        '22:30 — отчёт',
      ],
      faq: _commonFaq,
    ),
    'live-communication': HabitProgramMeta(
      dailyAction:
          'Один живой контакт: звонок, голосовое или встреча без переписки вместо общения.',
      outcome: 'Больше настоящего контакта, меньше «мертвых» чатов',
      difficulty: 'Средняя',
      timeOfDay: 'Любое',
      durationLabel: '10–20 мин',
      reportFormat: 'С кем связались и что дали друг другу',
      skipPolicy: 'Короткое голосовое сообщение считается.',
      teamRole: 'Команда моделирует поддерживающее общение.',
      sampleDay: const [
        '14:00 — 10 мин разговор с другом',
        '21:00 — отчёт',
      ],
      faq: _commonFaq,
    ),
  };
}
