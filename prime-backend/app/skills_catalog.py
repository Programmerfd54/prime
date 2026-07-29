"""Official skills catalog — extracted from routers/misc.py."""

SKILLS = [
    {
        "id": "live-communication",
        "name": "Живое общение",
        "description": "Ежедневная практика живого контакта, внимания к собеседнику и осознанной коммуникации.",
        "icon": "forum",
        "category": "official",
        "popularity": 1,
    },
    {
        "id": "digital-detox",
        "name": "Цифровой детокс",
        "description": "Снижение экранного времени, отказ от лишних отвлечений и возврат внимания.",
        "icon": "phone_disabled",
        "category": "official",
        "popularity": 2,
    },
    {
        "id": "one-chapter",
        "name": "Одна глава",
        "description": "Каждый день читать минимум одну главу и закреплять привычку регулярного обучения.",
        "icon": "menu_book",
        "category": "official",
        "popularity": 3,
    },
    {
        "id": "morning-focus",
        "name": "Утренний фокус",
        "description": "Спокойное утро без телефона, с главным намерением дня и первым осознанным действием.",
        "icon": "wb_sunny",
        "category": "official",
        "popularity": 4,
    },
    {
        "id": "body-charge",
        "name": "Зарядка для тела",
        "description": "Короткая ежедневная физическая активность, чтобы держать тело в тонусе.",
        "icon": "fitness_center",
        "category": "official",
        "popularity": 5,
    },
    {
        "id": "evening-ritual",
        "name": "Вечерний ритуал",
        "description": "Завершение дня без хаоса: подготовка ко сну, рефлексия и восстановление.",
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
