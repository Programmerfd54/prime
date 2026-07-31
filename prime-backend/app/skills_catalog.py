"""Official skills catalog — extracted from routers/misc.py."""

SKILLS = [
    {
        "id": "live-communication",
        "name": "Живое общение",
        "description": (
            "Общение — это не лайки и комментарии. Каждый день — один осознанный "
            "разговор с человеком рядом. Без телефона, без спешки."
        ),
        "icon": "forum",
        "category": "official",
        "popularity": 1,
    },
    {
        "id": "digital-detox",
        "name": "Цифровой детокс",
        "description": (
            "Замените 45 минут бесцельного скролла на то, что вас реально зажигает. "
            "Рисуйте, готовьте, гуляйте, создавайте."
        ),
        "icon": "phone_disabled",
        "category": "official",
        "popularity": 2,
    },
    {
        "id": "one-chapter",
        "name": "Одна глава",
        "description": (
            "Одна глава в день — от 5 страниц — и через месяц вы прочитаете "
            "целую книгу. Главное — записывать главную мысль."
        ),
        "icon": "menu_book",
        "category": "official",
        "popularity": 3,
    },
    {
        "id": "morning-focus",
        "name": "Утренний фокус",
        "description": (
            "Начни день с ясной головой. Первые 40 минут после пробуждения — "
            "без экрана. Ты управляешь утром — а не оно тобой."
        ),
        "icon": "wb_sunny",
        "category": "official",
        "popularity": 4,
    },
    {
        "id": "body-charge",
        "name": "Зарядка для тела",
        "description": (
            "Каждое утро — 10 минут зарядки. Три вечера в неделю — короткая "
            "силовая, чтобы стать сильнее."
        ),
        "icon": "fitness_center",
        "category": "official",
        "popularity": 5,
    },
    {
        "id": "evening-ritual",
        "name": "Вечерний ритуал",
        "description": (
            "За час до сна — телефон вне спальни. Тёплый душ, чай, книга. "
            "Вы заслуживаете качественного отдыха."
        ),
        "icon": "dark_mode",
        "category": "official",
        "popularity": 6,
    },
]




def skill_name(skill_id: str | None) -> str | None:
    if not skill_id:
        return None
    for skill in SKILLS:
        if skill["id"] == skill_id:
            return skill["name"]
    return skill_id
