import '../../l10n/copy.dart';
import '../../models/skill.dart';

/// Report tips per skill — photo / video / text template.
class HabitReportTips {
  const HabitReportTips({
    required this.photo,
    required this.video,
    required this.textTemplate,
  });

  final String photo;
  final String video;
  final String textTemplate;
}

/// Static program facts from product copy — single source of truth for habit UX.
class HabitProgramMeta {
  const HabitProgramMeta({
    required this.shortDescription,
    required this.dailyAction,
    required this.dailySteps,
    required this.outcome,
    required this.difficulty,
    required this.timeOfDay,
    required this.durationLabel,
    required this.reportFormat,
    required this.reportTips,
    required this.skipPolicy,
    required this.teamRole,
    required this.sampleDay,
    required this.faq,
  });

  final String shortDescription;
  final String dailyAction;
  final List<String> dailySteps;
  final String outcome;
  final String difficulty;
  final String timeOfDay;
  final String durationLabel;
  final String reportFormat;
  final HabitReportTips reportTips;
  final String skipPolicy;
  final String teamRole;
  final List<String> sampleDay;
  final List<HabitFaqItem> faq;

  String get cycleNote => AppCopy.cycleContinuationFootnote;

  /// Compact coach steps shown on active cycle (first 5).
  List<String> get coachSteps => dailySteps.take(5).toList();
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

  static HabitProgramMeta? metaForId(String? skillId) {
    if (skillId == null || skillId.isEmpty) return null;
    return _byId[skillId];
  }

  static HabitProgramMeta _defaultMeta(SkillModel skill) {
    final desc = skill.description.trim();
    return HabitProgramMeta(
      shortDescription: desc.isNotEmpty ? desc : 'Ежедневная практика с командой',
      dailyAction: desc.isNotEmpty ? desc : 'Ежедневное действие по программе',
      dailySteps: desc.isNotEmpty ? [desc] : const ['Ежедневное действие по программе'],
      outcome: 'Устойчивый ритм на ${AppCopy.cycleDays}',
      difficulty: 'Средняя',
      timeOfDay: 'Любое',
      durationLabel: '10–20 мин',
      reportFormat: 'Текст и при желании фото',
      reportTips: const HabitReportTips(
        photo: 'Сфотографируйте процесс или результат',
        video: 'Короткое видео до 30 секунд',
        textTemplate: 'День [N]. Практика выполнена. Чувствую [состояние].',
      ),
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
    HabitFaqItem(
      question: '30 дней — это всё?',
      answer:
          'Нет. 30 дней — первый цикл. Если привычка приносит пользу, продолжайте 90, 180 или 365 дней.',
    ),
  ];

  static final _byId = <String, HabitProgramMeta>{
    'morning-focus': HabitProgramMeta(
      shortDescription:
          'Начни день с ясной головой. Первые 40 минут после пробуждения — без экрана. '
          'Ты управляешь утром — а не оно тобой.',
      dailyAction:
          '40 минут без экрана: вода + дыхание + планирование дня с одной главной целью.',
      dailySteps: const [
        'Проснувшись, не брать телефон. Первые 40 минут — никаких экранов.',
        'Встать и выпить стакан воды, глядя в окно (порция света).',
        'Дыхательная практика 3–5 мин: 5–10 глубоких вдохов, наблюдение за дыханием.',
        'Записать одну главную цель дня и до 3 ключевых дел.',
        'По желанию — благодарности за прошлый день.',
      ],
      outcome:
          'Спокойное, собранное начало дня. Ясная голова и намерение вместо реактивного скролла.',
      difficulty: 'Средняя',
      timeOfDay: 'Утро',
      durationLabel: '40 мин',
      reportFormat: 'Фото страницы дневника, короткое видео или текст с целью дня',
      reportTips: const HabitReportTips(
        photo: 'Сфотографируйте страницу дневника с целью на день',
        video: 'До 30 сек: как прошла утренняя практика, что чувствуете',
        textTemplate:
            'День [N]. Утренняя практика выполнена. Сегодняшняя цель — [цель]. Чувствую [бодрость/спокойствие/ясность].',
      ),
      skipPolicy:
          'Если пропустили утро — отметьте «не готов» и напишите команде план на вечер.',
      teamRole: 'Команда делится утренними якорями — без соревнования «кто раньше».',
      sampleDay: const [
        '07:00 — вода + свет из окна',
        '07:10 — дыхание 5 мин',
        '07:20 — дневник: цель и 3 дела',
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
    'live-communication': HabitProgramMeta(
      shortDescription:
          'Общение — это не лайки и комментарии. Это живые голоса, улыбки, взгляды. '
          'Каждый день — один осознанный разговор. Без телефона, без спешки.',
      dailyAction:
          'Один живой разговор 15+ минут: коллега, друг, семья или сосед — без телефона на столе.',
      dailySteps: const [
        'Инициируйте или продолжите один живой разговор (15+ минут).',
        'Телефон убран — всё внимание собеседнику.',
        'Задавайте открытые вопросы: «Как ты?», «Что вдохновляет?»',
        'Слушайте активно: не перебивайте, уточняйте, проявляйте интерес.',
      ],
      outcome:
          'Развивает навык эффективных коммуникаций: точнее понимать людей и ярче '
          'испытывать эмоции в ежедневной жизни.',
      difficulty: 'Средняя',
      timeOfDay: 'Любое',
      durationLabel: '15+ мин',
      reportFormat: 'Селфи с согласия, фото места разговора или текст с инсайтом',
      reportTips: const HabitReportTips(
        photo: 'Селфи с собеседником (по согласию) или фото места разговора',
        video: 'До 30 сек: инсайт из разговора',
        textTemplate:
            'День [N]. Поговорил(а) с [имя]. Обсуждали [тему]. Чувствую [тепло/близость/вдохновение].',
      ),
      skipPolicy: 'Короткое голосовое сообщение считается, если нет возможности встретиться.',
      teamRole: 'Команда моделирует поддерживающее общение.',
      sampleDay: const [
        '14:00 — 15 мин разговор без телефона',
        '21:00 — отчёт в группе',
      ],
      faq: _commonFaq,
    ),
    'one-chapter': HabitProgramMeta(
      shortDescription:
          'Чтение интересной и полезной книги — лучший тренажёр для мозга. '
          'Одна глава в день — от 5 страниц — и через месяц вы прочитаете целую книгу.',
      dailyAction:
          'Прочитать минимум 5 страниц или одну главу и записать 1–2 ключевые мысли.',
      dailySteps: const [
        'Выберите книгу, которая вдохновляет (без уведомлений в читалке).',
        'Прочитайте минимум 5 страниц или одну главу.',
        'Выделите 1–2 ключевые мысли или цитаты и запишите в блокнот.',
      ],
      outcome:
          'Регулярное чтение без перегруза. Через месяц — целая книга и привычка думать о прочитанном.',
      difficulty: 'Лёгкая',
      timeOfDay: 'Вечер',
      durationLabel: '20–40 мин',
      reportFormat: 'Фото книги или блокнота с мыслью + количество страниц',
      reportTips: const HabitReportTips(
        photo: 'Книга или блокнот с записанной мыслью (укажите страницы)',
        video: 'До 30 сек: о чём прочитали и какая мысль откликнулась',
        textTemplate:
            'День [N]. Прочитал(а) [N] страниц «[Название]». Главная мысль: [идея]. Планирую применить: [как].',
      ),
      skipPolicy: 'Можно сократить до 5 страниц — но отметить в отчёте.',
      teamRole: 'Обмен рекомендациями книг в чате.',
      sampleDay: const [
        '21:00 — одна глава',
        '21:30 — отчёт с цитатой или мыслью',
      ],
      faq: _commonFaq,
    ),
    'body-charge': HabitProgramMeta(
      shortDescription:
          'Тело — ваш главный инструмент. Каждое утро — 10 минут зарядки, '
          'чтобы разбудить мышцы. Три вечера в неделю — короткая силовая.',
      dailyAction:
          'Утром 10 мин зарядки; 3 раза в неделю вечером — 20 мин силовой тренировки.',
      dailySteps: const [
        'Утро: суставная гимнастика 2 мин.',
        'Утро: 3×10 приседаний, отжиманий, планка 30 сек — 5 мин.',
        'Утро: дыхание 2 мин.',
        'Вечер (3×/нед): разминка, приседы, выпады, отжимания, супермен, заминка.',
      ],
      outcome:
          'Тело в тонусе без марафонов. Бодрость утром и сила без перегруза.',
      difficulty: 'Средняя',
      timeOfDay: 'Утро / вечер',
      durationLabel: '10–20 мин',
      reportFormat: 'Селфи после зарядки, видео упражнения или текст с самочувствием',
      reportTips: const HabitReportTips(
        photo: 'Селфи после зарядки или фото коврика / гантелей',
        video: 'До 30 сек: одно упражнение (например, планка)',
        textTemplate:
            'День [N]. Зарядка выполнена. Чувствую [бодрость/лёгкость]. Сегодня: [упражнения].',
      ),
      skipPolicy: 'Лёгкая прогулка считается, если нет сил на зарядку.',
      teamRole: 'Поддержка без сравнения «кто больше шагов».',
      sampleDay: const [
        '08:00 — 10 минут зарядки',
        '21:00 — отчёт',
      ],
      faq: _commonFaq,
    ),
    'digital-detox': HabitProgramMeta(
      shortDescription:
          'Скроллинг крадёт не только время, но и энергию. Замените 45 минут '
          'бесцельного серфинга на то, что вас реально зажигает.',
      dailyAction:
          '45 минут на любимое хобби вместо скролла. Телефон — в другой комнате.',
      dailySteps: const [
        'Выберите хобби: рисование, музыка, готовка, прогулка, фото и т.д.',
        'Ежедневно 45 минут на это занятие.',
        'Телефон в другой комнате или режим «Не беспокоить».',
      ],
      outcome:
          'Меньше фонового скролла, больше энергии и радости от реальных занятий.',
      difficulty: 'Средняя',
      timeOfDay: 'День / вечер',
      durationLabel: '45 мин',
      reportFormat: 'Фото процесса, видео хобби или текст о замене скролла',
      reportTips: const HabitReportTips(
        photo: 'Процесс: рисунок, блюдо, инструменты',
        video: 'До 30 сек: вы занимаетесь любимым делом',
        textTemplate:
            'День [N]. Цифровой детокс: вместо скроллинга — [хобби]. Чувствую [спокойствие/радость].',
      ),
      skipPolicy: 'Честный отчёт «не готов» лучше молчания.',
      teamRole: 'Участники делятся лайфхаками без осуждения.',
      sampleDay: const [
        '18:00 — 45 мин хобби без телефона',
        '20:30 — отчёт',
      ],
      faq: _commonFaq,
    ),
    'evening-ritual': HabitProgramMeta(
      shortDescription:
          'Как вы завершаете день, так начинаете следующий. За час до сна — '
          'телефон вне спальни. Тёплый душ, чай, книга.',
      dailyAction:
          'За час до сна — телефон вне спальни. Ритуал: душ, чай, растяжка или чтение + 3 благодарности.',
      dailySteps: const [
        'За час до сна — телефон в другой комнате.',
        'Проветрите комнату (18–20°C — идеально для сна).',
        'Ритуал: душ, чай, растяжка 5–10 мин или чтение 10–15 мин.',
        'Запишите 3 хорошие вещи за день.',
        'Определите одну главную задачу на завтра.',
      ],
      outcome:
          'Качественный отдых и мягкое завершение дня. Лучше засыпание и спокойнее утро.',
      difficulty: 'Лёгкая',
      timeOfDay: 'Вечер',
      durationLabel: '20–60 мин',
      reportFormat: 'Фото уютного вечера, видео или текст с благодарностями',
      reportTips: const HabitReportTips(
        photo: 'Уютный вечер: чай + книга или кровать с пледом',
        video: 'До 30 сек: как прошёл вечер, 3 вещи из дневника',
        textTemplate:
            'День [N]. Вечерний ритуал выполнен. Благодарен(на) за [3 вещи]. Завтра: [цель]. Чувствую [спокойствие].',
      ),
      skipPolicy: 'Минимум 5 минут рефлексии, если день тяжёлый.',
      teamRole: 'Команда делится вечерними якорями.',
      sampleDay: const [
        '22:00 — телефон в другую комнату',
        '22:15 — три строки благодарности',
        '22:30 — отчёт',
      ],
      faq: _commonFaq,
    ),
  };
}
