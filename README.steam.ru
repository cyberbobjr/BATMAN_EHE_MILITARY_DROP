[h1]Military Drop - сброс снабжения по рации[/h1]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/banner.png[/img]

[b]Build 42.21 · Соло и сеть · Без зависимостей[/b]

[i]Для выделенных серверов; проверено только соло. Пишите о сетевых ошибках.[/i]

Военная рация и код недели вызывают снабжение. Координаты слышат все; шум манит мертвецов.

[b]BREAKING CHANGE — 0.1.2:[/b] репутация личная, старые оценки не переносятся (старт 25).

[h2]Частота и код[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-code.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/codebook-memo.png[/img]

Частота — в записках военных и полиции. По понедельникам кодовая книга расшифровывает КВ-передачу.

[h2]Вызов по рации[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-radio.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/walkie-logistics.png[/img]

ПКМ по военной рации → [b]Настроить устройство[/b] → [b]Снабжение[/b] → код → [b]Запросить сброс груза[/b].

[h2]Заявка[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-requisition.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/requisition-form.png[/img]

18 позиций добычи (и из модов) на очки. Или приманка с сиреной для отвода орд.

[h2]К ящику[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-crate.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/crate-trunk.png[/img]

Ящик в 150–400 клетках охраняет орда. Пустые ящики дают древесину.

[b]Держите рацию на военной частоте.[/b] Координаты и метка — при посадке и каждые 6 ч до открытия. Сохранить: [b]Добавить[/b].

[h2]Крушение вертолёта[/h2]

Вертолёт может разбиться, чаще в грозу; MAYDAY даёт сектор. У пилота — записка, кодовая книга и [b]бортовой самописец[/b]; обломки разбираются. Заказ теряется (опция сервера).

[h2]Доверие базы[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-trust.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/console-missions.png[/img]

Личное доверие сокращает ожидание и расширяет заявки. Старт 25; смена фракции не влияет.

[h3]Репутация[/h3]

Сброс — только заказчику, прочее — действующему. Время игровое, значения по умолчанию.

[table]
[tr][td][b]Причина[/b][/td][td][b]Изменение[/b][/td][/tr]
[tr][td]Заказчик открывает первый кейс[/td][td]+10[/td][/tr]
[tr][td]Член его фракции открывает первым[/td][td]+5[/td][/tr]
[tr][td]Посторонний открывает первым[/td][td]−5[/td][/tr]
[tr][td]Не открыто за 48 ч после доставки[/td][td]−10[/td][/tr]
[tr][td]Самописец передан, раз на крушение, вне лимита[/td][td]+10[/td][/tr]
[tr][td]Первый доклад за день[/td][td]+1[/td][/tr]
[tr][td]Каждый новый именной жетон[/td][td]+2[/td][/tr]
[tr][td]Первая разведка: 25 клеток / 48 ч[/td][td]+3[/td][/tr]
[tr][td]Больше всего убийств орды, 90% мертвы[/td][td]+5[/td][/tr]
[tr][td]Проверка связи за 4 ч, раз на персонажа[/td][td]+1[/td][/tr]
[tr][td]3 ошибки кода или частоты за 1 ч[/td][td]−2[/td][/tr]
[tr][td]Эрозия после 24 ч без связи (опция)[/td][td]−1 / +1[/td][/tr]
[/table]

Лимит +8/день без сбросов. Пост: доклад +2, жетон +3, разведка +5, связь +2. Шкала 0–100; ниже 15 — без связи 3 дня. Админ, приманки: 0. Эрозия (выкл.) — к 25.

[h2]Пост связи[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-post.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/console.png[/img]

Стационарная военная рация — общий пульт: дела, приказы, журнал, сбросы. Самописец читается за 10 минут. Позывной у фракции, доверие личное.

[h2]Зоны сброса (PvP)[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/zones-add.png[/img]

PvP: админ задаёт места сброса — зоны по секторам (парк, ТЦ, дома в Луисвилле). Ближайший или случайный сектор, затем зона по весу: место не закемпить. В эфире — имя зоны; по опции игрок выбирает сектор (и для приманки). Не в воде, зданиях, зонах без PvP и убежищах.

Панель в игре ([b]Зоны сброса[/b]): рисование мышью, сектор, вес, [b]Подсветка[/b], правка, телепорт. Выкл. по умолчанию.

[h2]Админам[/h2]

[list]
[*]60 настроек, без перезапуска (кроме частот); ожидание сброса — неделя на весь сервер.
[*]Позиции заявки: Zomboid/Lua/MilitaryDrop/requisition.txt.
[*]Админ с рации: сброс, крушение, задания.
[/list]

[h2]Совместимость[/h2]

[list]
[*]Другие моды не требуются.
[*]Совместим с [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3672792485]HEF - Helicopter Event Framework[/url].
[*]С [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3811010882]Signal Smoke[/url] ящик отмечает зелёный дым.
[*]Совместим с Better Walkie Talkies (его PTT, голос и батарея).
[*]Предметы из ваших модов появляются в ящиках.
[/list]

[h2]Гайд[/h2]

Подробно: [url=https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/wiki/EN-Home]full guide (English)[/url] · [url=https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/wiki/FR-Home]guide complet (français)[/url].

[h2]Поддержка[/h2]

Кофе поможет проекту.
[url=https://ko-fi.com/Z8Z8QJV31][img]https://storage.ko-fi.com/cdn/kofi6.png?v=6[/img][/url]

[h2]Благодарности[/h2]

Версия B42 мода [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085]Expanded Helicopter Events: Drop Military Cargo[/url] (Build 41). Код (MIT) на [url=https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP]GitHub[/url].
