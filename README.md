*README is partially in russian as it was (totaly russian) initially*

*livegazer* is a program to track changes on HTTP site.

# Goals

*livegazer* полезен, чтобы не торчать все время в ЖЖ, а быстро вычитывать
новое, только существенное. Возможно чтобы в `otdam_darom` отлавливать
посты с ключевыми словами чтобы оперативно реагировать на новое.

*livegazer* не предполагается на данный момент как инструмент для удобного
просмотра журнала с картинками.

# Description

*livegazer* is program to track changes on webpages. It installs status
icon to tray and that's the main user interface. When something new is
detected the icon changes. There is a tooltip associated with status
icon. Upon update it contains summary of what happened.

When started *livegazer* reads config file (livegazerrc for now).
Config file has [YAML](http://yaml.org) format.
It contains array of settings. Each setting describes URL for tracking
and miscellaneous parameters such as update period and login
information (if there is some actions user have to do in order to access
the URL). For each setting an icon is created in tray.

# Done

## Configuration

     Обязательные настройки для сайта:
        URL
     Дополнительные:
        период 
        иконки
        атрибуты логина:
           URL
           логин
           пароль
     Расширенные:
        настройка извлечения текста

## Structure

Fetcher downloads a webpage logging in if needed. It can also check
whether there are updates available using basic HTTP properties such as
Last-Modified or (in future probably) Etag (by HEAD request).

Crawler controls fetchers. It serves the task of simultaneous download of
multiple pages. Each fetcher is run in separate thread and crawler
restarts fetchers if there are network errors.

Extractor manages history of a page. It can parse page updates and
generates update summaries. And it stores history in appropriate data
structure. As such there may be different extractors for user to choose
from. Extractors are major extensions of *livegazer*.

# Идеи

Сделать более гибким формат конфигурационного файла (чтобы можно было
например указать только URL, даже без ключа `url:`).

Возможно сделать возможность указать метод логина и как передавать
сессию (cookie, get).

Показывать максимально удобно diff. Можно писать лог всех зафиксированных состояний текстов.

Можно сделать различные управляющие воздействия:

* Отметить как прочитанное (click)
* Открыть (middle-click)
* Открыть и отметить как прочитанное (ctrl-click)

Что делать при открытии должно настраиваться (команды для различных
браузеров).

Что делать при обнаружении новостей тоже можно настраивать (проигрывать
звук).

Можно сделать воздействия на отдельные элементы текста (посты
например) и показывать, что есть непрочитанное, пока не все посты
отмечены.

В дальнейшем можно и RSS прикрутить, но скорее всего это лишнее,
разве что если его использовать только для отслеживания обновления.
Можно модели текстов и преобразования в модели текстов сделать
плагинами.

Можно пробовать классифицировать посты (заметка, творческий пост,
фотоотчет и т.п.). Можно просто добавлять пометки "с картинками".

Модели текста:

* Тривиальный - один текст
* Простой - массив текстов
* ЖЖ - массив (заголовков, текстов, комментариев)
* ...

Выкачивание и вся обработка должны быть в отдельной нити (может быть в
нескольких нитях).

Для ЖЖ можно было бы сделать переход по ссылке для написания
комментария.

Можно сделать добавление URL-ов online.
Так как StatusIcon не является widget-ом, можно попробовать
вытаскивать из буфера обмена адрес например по ctrl-middle-click.
Ну либо добавлять через меню.
Также удаление и отключение URL-ов.

В меню можно перечислять сайты и ставить напротив них галочки.
И можно щелкать по ним, чтобы настраивать в окошках.

Если будут окошки, то уже пригодится логотип.

Можно вместо стандартного Tooltip показывать свое окошко, с более
продвинутой версткой.

Возможно иногда придется делать перелогиневание.

В ЖЖ без логина есть реклама, а с логином нет (и можно по Last-Modified
отсекать).

В принципе если возвращается не HTML, а например картинка, можно было бы
тоже отслеживать изменения.

Можно скроллингом на иконке прокручивать содержимое тултипа.

Если несколько сайтов сразу, то нужно либо несколько иконок в трее,
либо одну общую.

Можно как-то сообщать также заодно о недоступности серверов.

Нужно как-то следить за съезжающим markup-ом, из-за которого появляются
ошибки в консоли и ничего в тултипе не отрисовывается.
Учитывая, что отображаются пользовательские данные, это особенно важно.

Нужно сделать запись в лог. Установку через gem или как-то ещё.
Настройку. Добавить в репозиторий пример конфига.
Сделать описание и список доделок для github.
Придумать лицензию.

Можно сделать указание иконок тоже URL-ом.

Возможно отдельный конфиг для сайтов и отдельный для настроек (например
действия при щелчке мыши).

# Проектирование

## Модули

Скачивание

Работа с данными на основе плагинов (для разных сайтов)

Пользовательский интерфейс

## Действия

Инициализация

Скачивание страницы

    Работает в отдельной нити. Проверяет URL с заданным интервалом.
    Когда по предварительной проверке (Last-Modified, возможно MD5)
    видно, что документ возможно обновился, посылает его в очередь
    для основной нити.
 
    Основная нить умеет добавлять и удалять страницы на скачивание.
    Каждый URL скачивается в своей нити.

Извлечение информации

Сравнение 

Формирование обзора

Обслуживание интерфейса

    Действие при появление новостей
 
    Показывание иконки / смена иконки
 
    Показывание тултипа
 
    Щелчок мыши -- сбрасывание истории
 
    Щелчок мыши -- выполнение команды
 
    Щелчок мыши -- добавление и настройка новых адресов

## Данные

Накопленная история

## Нити

Для начала по нити на URL, занимаются исключительно скачиванием.

Нить для подготовки данных для пользователя

Основная нить с графическим интерфейсом

# TODO

* Documentation
    * Config format
    * Comments
    * Description (user and developer)
* Translate to english
* Handsome site config (probably during program work)
* Installation procedure
* First start procedure
* Надежная загрузка конфигурационного файла
    * Отсутствие файла
    * Ошибки формата
    * Период по умолчанию
    * Иконки по умолчанию
    * Отсутствие файлов иконок
    * Extractor по умолчанию

# BUGS

`<lj-user>`-ы почему-то не показываются

# Информация

[Pango format](http://library.gnome.org/devel/pango/stable/PangoMarkupFormat.html) for `tooltip_markup`.

[Gtk::StatusIcon Description](http://ruby-gnome2.sourceforge.jp/hiki.cgi?Gtk%3A%3AStatusIcon).
