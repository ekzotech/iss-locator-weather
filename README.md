# Погода под МКС

Трекер положения Международной космической станции на Perl и Mojolicious. Сборщик раз в минуту получает координаты из Open Notify, запрашивает текущую погоду Open-Meteo для точек над сушей и сохраняет результат в SQLite. На странице отображаются карта, последний снимок и журнал наблюдений.

## Установка

Потребуются Perl 5.26 или новее, cpanminus и зависимости из `cpanfile`. SQLite поставляется с модулем `DBD::SQLite`.

В Linux установите Perl, cpanminus, инструменты сборки и заголовки OpenSSL. Например, в Debian или Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y perl cpanminus build-essential libssl-dev
cpanm --mirror https://cpan.metacpan.org --mirror-only --local-lib .local --installdeps .
```

В Windows используйте Strawberry Perl. Откройте PowerShell в корне репозитория. Если Perl не находится в `PATH`, добавьте каталоги вашей установки. Для стандартного расположения:

```powershell
$env:Path = "C:\Strawberry\perl\bin;C:\Strawberry\c\bin;" + $env:Path
cpanm.bat --mirror https://cpan.metacpan.org --mirror-only --local-lib .local --installdeps .
```

## Запуск

Откройте два терминала в корне проекта. Команды одинаковы в Linux и PowerShell. Если в Windows путь к Strawberry Perl был добавлен только на время сеанса, повторите настройку `PATH` во втором терминале.

1. Запустите веб-сервер.

   ```sh
   perl -I.local/lib/perl5 script/iss_tracker daemon -l http://127.0.0.1:3000
   ```

2. Запустите сборщик.

   ```sh
   perl -I.local/lib/perl5 script/iss_tracker collect
   ```

Откройте [локальную страницу](http://127.0.0.1:3000/). Первый цикл запускается сразу. Для одного цикла используйте `collect --once`. `Ctrl+C` останавливает сборщик после завершения активного цикла.

Оба процесса по умолчанию используют `var/observations.sqlite`. При первом запуске приложение создаёт каталог и применяет миграции. Для отдельной базы задайте обоим процессам одинаковое значение `ISS_TRACKER_DB`. Относительный путь отсчитывается от рабочей папки.

## Проверки

```sh
prove -I.local/lib/perl5 -r t
```

В PowerShell команда `prove.bat -I.local/lib/perl5 -r t` запускает тот же набор. Тесты используют временные файлы SQLite и локальные HTTP-моки Test::Mojo.

## Офлайн-демо

```sh
perl -I.local/lib/perl5 script/iss_demo
```

Откройте [демонстрационную страницу](http://127.0.0.1:3001/). Демо заполняет временную SQLite девятью фиктивными наблюдениями и запускает веб-сервер. После установки зависимостей для него достаточно локального соединения.

[План проекта](PLAN.md)

## API приложения

Все маршруты доступны без ключей и возвращают JSON.

| Запрос | Ответ |
| --- | --- |
| `GET /health` | `{"status":"ok"}`, если веб-процесс отвечает |
| `GET /api/latest` | Последнее наблюдение в поле `observation`. В пустой базе ответ `{"observation":null}` |
| `GET /api/history?limit=20&before=1704067260` | `observations` от новых к старым и `next_before` для следующей страницы |
| `GET /api/track` | `points` с координатами и временем за два часа до последней записи, от старых к новым |
| `GET /api/dashboard` | HTML-фрагменты `snapshot`, `history_rows`, `map_overlay`, описание `map_description` и курсор `next_before` |

Размер страницы по умолчанию — 20 записей, максимум — 100. Курсор `before` исключает наблюдения с этим и более поздним временем. Если страниц больше нет, `next_before` равен `null`. Неверный лимит или курсор возвращает HTTP 400 с полем `error`. Вариант `view=html` возвращает `history_rows` вместе с `next_before` для кнопки «Показать более ранние пролёты».

У наблюдения есть координаты `latitude` и `longitude` в градусах, `observed_at` и `weather_at` в Unix-секундах, температура `temperature_c` в °C, облачность `cloud_cover` в процентах и `weather_code` по WMO. Поле `display` содержит готовые подписи и время в UTC. `weather_status` принимает значения `available`, `water` или `unavailable`. Для двух последних статусов погодные поля равны `null`.

## Источники и точность

- Координаты поступают из Open Notify. Документированный URL использует HTTP. Если источник не отвечает, журнал показывает последнюю сохранённую точку. Через три минуты снимок получает отметку об устаревании. [Open Notify API](https://github.com/open-notify/Open-Notify-API)
- Open-Meteo возвращает данные модели для ближайшей ячейки. Модель обновляется с другой частотой, поэтому время погоды показано отдельно. Бесплатный endpoint предназначен для некоммерческого использования. [Документация Open-Meteo](https://open-meteo.com/en/docs), [условия использования](https://open-meteo.com/en/terms)
- Для суши и карты используются контуры Natural Earth масштаба 1:110 млн. Детализация островов и береговой линии ограничена. Приложение определяет сушу по контурам без поиска ближайшего города. [Происхождение набора](data/README.md)

Для подмены провайдеров задайте `ISS_TRACKER_ISS_URL` и `ISS_TRACKER_WEATHER_URL`. Сборщик ожидает формат JSON соответствующих API.
