/// Единый словарь терминов и пользовательских сообщений (RU).
abstract final class AppCopy {
  // Product terms
  static const habit = 'привычка';
  static const habits = 'Привычки';
  static const team = 'команда';
  static const group = 'группа';
  static const cycle = 'цикл';
  static const cycleDays = '30 дней';
  static const primes = 'Праймы';
  static const report = 'отчёт';
  static const streak = 'Дней подряд';
  static const successfulDays = 'Успешных дней';
  static const findTeam = 'Найти команду';
  static const searchingTeam = 'Ищем команду…';
  static const stopSearch = 'Остановить поиск';
  static const findFriend = 'Найти друга';
  static const confirmParticipation = 'Подтвердить участие';
  static const teamReadyConfirm =
      'Команда готова. Подтвердите участие';
  static const customHabitLocked = 'Нужно 10 Праймов · скоро';
  static const deleteAccountUnavailable = 'Пока недоступно';
  static const emailAlreadyRegistered =
      'Этот email уже зарегистрирован. Войдите в аккаунт.';
  static const switchToLogin = 'Войти с этим email';
  static const aboutJunk =
      'О себе выглядит как набор символов или повтор. Напишите своими словами — минимум 3 разных слова.';
  static const primesExplainer =
      'Праймы — очки за полные командные дни. День закрывается, только когда отчитались все участники команды; тогда +1 Прайм каждому.';
  static const multiQueueHint =
      'Можно искать сразу несколько привычек. Стартёт первая собранная команда — остальные поиски можно остановить.';
  static const waitPrepTip =
      'Пока ждёте: перечитайте «О себе» и подготовьте, как будете отчитываться каждый день.';

  // Team day
  static const dayClosesTogether = 'День закрывается вместе';
  static const primesForTeamDay = 'Прайм — за полный день команды';
  static const reportSavedStreakSafe =
      'Ваш отчёт сохранён — серия не сгорит';
  static const nudgeTeam = 'Напомнить команде';
  static const inviteFriend = 'Пригласить друга';
  static const howDayCounts =
      'День засчитывается всей команде, только когда отчитались все. Если кто-то не сдал отчёт — день не закрыт никому, но ваша серия не обнуляется.';

  static String waitingReports(int n) {
    if (n <= 0) return 'Ждём команду';
    if (n == 1) return 'Ждём 1 отчёт';
    if (n >= 2 && n <= 4) return 'Ждём $n отчёта';
    return 'Ждём $n отчётов';
  }

  // Generic actions
  static const retry = 'Повторить';
  static const continueLabel = 'Продолжить';
  static const skip = 'Пропустить';
  static const save = 'Сохранить';
  static const cancel = 'Отмена';
  static const back = 'Назад';
  static const writeMessage = 'Написать';

  // Errors
  static const validation =
      'Проверьте введённые данные и повторите попытку.';
  static const unauthorized =
      'Сессия истекла. Войдите в аккаунт снова.';
  static const invalidCredentials =
      'Неверная почта или пароль. Проверьте данные или восстановите пароль.';
  static const nicknameTaken = 'Этот никнейм уже занят.';
  static const agreementRequired =
      'Нужно принять пользовательское соглашение и политику конфиденциальности.';
  static const forbidden =
      'Недостаточно прав для этого действия.';
  static const notFound =
      'Не удалось найти нужные данные. Обновите экран и попробуйте снова.';
  static const endpointUnavailable =
      'Сервер не поддерживает это действие. Обновите API или повторите позже.';
  static const passwordResetUnavailable =
      'Сброс пароля сейчас недоступен на сервере. Перезапустите API с актуальным кодом или войдите, если помните пароль.';
  static const passwordResetInvalidToken =
      'Код восстановления недействителен или истёк. Запросите новый.';
  static const conflict =
      'Конфликт данных. Возможно, никнейм или email уже заняты.';
  static const payloadTooLarge =
      'Файл слишком большой. Уменьшите размер и попробуйте снова.';
  static const rateLimit =
      'Слишком много попыток. Подождите немного и повторите действие.';

  static String rateLimitWithRetry(int seconds) {
    if (seconds <= 0) return rateLimit;
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    if (minutes > 0) {
      return 'Слишком много попыток. Повторите через $minutes мин ${rem > 0 ? '$rem с' : ''}'
          .trim();
    }
    return 'Слишком много попыток. Повторите через $seconds с.';
  }
  static const server =
      'Не удалось выполнить действие из-за технической ошибки. Повторите попытку или сообщите в поддержку.';
  static const serviceUnavailable =
      'Сервис временно недоступен. Мы уже пытаемся восстановить работу. Повторите попытку позже.';
  static const timeout =
      'Сервер не отвечает. Можно смотреть сохранённые данные, а действия с сетью повторить позже.';
  static const network =
      'Нет соединения с интернетом. Проверьте сеть — введённые данные сохранятся.';
  static const unknown =
      'Не удалось выполнить действие. Повторите попытку.';

  static const copyCode = 'Скопировать код';
  static const codeCopied = 'Код скопирован';
  static const unexpectedError =
      'Что-то пошло не так. Перезапустите экран или вернитесь назад.';

  static String supportHint(String? correlationId) {
    if (correlationId == null || correlationId.isEmpty) {
      return 'Если ошибка повторяется, напишите в поддержку.';
    }
    return 'Если ошибка повторяется, напишите в поддержку и укажите код: $correlationId';
  }
}
