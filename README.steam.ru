[h1]Military Drop - сброс снабжения по рации[/h1]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/banner.png[/img]

[b]Build 42.21 · Одиночная и сетевая игра · Без зависимостей[/b]

[i]Для выделенных серверов; проверен пока только соло. Сообщайте о сетевых ошибках.[/i]

Военная рация и код недели вызывают снабжение. Координаты слышат все в эфире; шум притягивает мертвецов.

[b]BREAKING CHANGE — 0.1.2:[/b] Репутация теперь личная; старые оценки не переносятся, все начинают с 25.

[h2]Найдите частоту и код[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-code.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/codebook-memo.png[/img]

Частота — в записках военных и полиции. По понедельникам кодовая книга расшифровывает КВ-передачу.

[h2]Вызов по рации[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-radio.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/walkie-logistics.png[/img]

ПКМ по военной рации → [b]Настроить устройство[/b] → [b]Снабжение[/b] → код → [b]Запросить сброс груза[/b].

[h2]Заполните заявку[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-requisition.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/requisition-form.png[/img]

18 позиций добычи, включая моды, на бюджет очков. Или приманка с сиреной для отвода орд.

[h2]Доберитесь до ящика[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-crate.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/crate-trunk.png[/img]

Ящик в 150–400 клетках охраняет орда. Пустые ящики дают древесину.

[b]Рация должна быть включена на военной частоте.[/b] Координаты и метка при посадке и каждые 6 ч до открытия; иначе их нет. Сохранить: [b]Добавить[/b].

[h2]Крушение вертолёта[/h2]

Вертолёт снабжения может разбиться, чаще в грозу. Его MAYDAY даёт сектор на военной частоте. У пилота — записка, кодовая книга и [b]бортовой самописец[/b]; снимите детали с обломков. Груз всё равно прибудет.

[h2]Заслужите доверие базы[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-trust.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/console-missions.png[/img]

Личное доверие сокращает ожидание и расширяет заявки. Старт: 25, смена фракции его не меняет.

[h3]Репутация: награды и штрафы[/h3]

Сброс влияет только на заказчика; прочее — на действующего. Игровое время, значения по умолчанию.

[table]
[tr][td][b]Причина[/b][/td][td][b]Изменение[/b][/td][/tr]
[tr][td]Заказчик открывает первый кейс[/td][td]+10[/td][/tr]
[tr][td]Член фракции вызова открывает первым[/td][td]+5[/td][/tr]
[tr][td]Посторонний открывает первым[/td][td]−5[/td][/tr]
[tr][td]Ничего не открыто за 48 ч после доставки[/td][td]−10[/td][/tr]
[tr][td]Самописец прочитан и передан, раз на крушение, вне лимита[/td][td]+10[/td][/tr]
[tr][td]Первый доклад за день[/td][td]+1[/td][/tr]
[tr][td]Каждый новый именной жетон[/td][td]+2[/td][/tr]
[tr][td]Первая разведка: 25 клеток / 48 ч[/td][td]+3[/td][/tr]
[tr][td]Больше всего убийств орды, 90% мертвы[/td][td]+5[/td][/tr]
[tr][td]Проверка связи за 4 ч, раз на персонажа[/td][td]+1[/td][/tr]
[tr][td]3 ошибки кода или частоты за 1 ч[/td][td]−2[/td][/tr]
[tr][td]Эрозия после 24 ч без связи (опция)[/td][td]−1 / +1[/td][/tr]
[/table]

Лимит +8/день, кроме сбросов. Пост: доклад +2, жетон +3, разведка +5, связь +2. Репутация 0–100; ниже 15 — без связи 3 дня. Сбросы админа, приманки: 0. Эрозия (выкл.) ведёт к 25.

[h2]Держите пост связи[/h2]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/art-post.png[/img]

[img]https://raw.githubusercontent.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/main/docs/steam/console.png[/img]

Стационарная военная рация — общий пульт: дела (самописцы, жетоны), приказы, журнал, сбросы. Отсек чтения читает самописец за 10 минут. У фракции свой позывной, доверие личное.

[h2]Для администраторов[/h2]

[list]
[*]60 настроек; ожидание сброса — неделя на весь сервер.
[*]Позиции заявки правятся в Zomboid/Lua/MilitaryDrop/requisition.txt.
[*]PvP: зоны сброса задаёт админ (dropzones.txt или в игре).
[*]Админы вызывают сбросы, крушение и задания с рации; всё решает сервер.
[/list]

[h2]Совместимость[/h2]

[list]
[*]Другие моды не требуются.
[*]Создан для совместной работы с [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3672792485]HEF - Helicopter Event Framework[/url].
[*]С [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3811010882]Signal Smoke[/url] ящик отмечает зелёный дым.
[*]Совместим с Better Walkie Talkies (его PTT, голос и батарея).
[*]Предметы из ваших модов появляются в ящиках.
[/list]

[h2]Руководство[/h2]

Все подробности со скриншотами: [url=https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/wiki/EN-Home]full guide (English)[/url] · [url=https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP/wiki/FR-Home]guide complet (français)[/url].

[h2]Поддержать проект[/h2]

Кофе поддержит новые функции и переводы.
[url=https://ko-fi.com/Z8Z8QJV31][img]https://storage.ko-fi.com/cdn/kofi6.png?v=6[/img][/url]

[h2]Благодарности[/h2]

Переработка для Build 42 мода [url=https://steamcommunity.com/sharedfiles/filedetails/?id=3259615085]Expanded Helicopter Events: Drop Military Cargo[/url] (Build 41). Исходный код (MIT) на [url=https://github.com/cyberbobjr/BATMAN_EHE_MILITARY_DROP]GitHub[/url].
