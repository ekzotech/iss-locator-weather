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

[План проекта](PLAN.md)
