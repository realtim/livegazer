*README is partially in russian as it was (totaly russian) initially*

*livegazer* is a program to track changes on HTTP sites.

It's goals are:

* Track changes important to user
* Rapidly notify about updates
* Save user's time and attention

# Description

*livegazer* is program to track changes on webpages. It installs status
icon to tray and that's the main user interface. When something new is
detected the icon changes. There is a tooltip associated with status
icon. Upon update it contains summary of what happened.

When started *livegazer* reads config file (livegazerrc for now).
Config file has [YAML](http://yaml.org) format.
It contains array of sections. Each section describes URL for tracking
and miscellaneous settings such as update period and login
information (if there is some actions user have to do in order to access
the URL). For each section an icon is created in tray.

# Configuration

Each section is started with "-" in first column (as array item in
YAML).

Obligatory fields:

* URL *(url)*
* Title *(title)*
* Update period *(period)*
* Icons *(icon/new,old)*
* Extractor -- plugin for handling webpage content -- look below *(extractor)*

Optional are fields regarding login information (some webpages doesn't
require login). Login fields are under *(login)*:

* Login url -- where login and password are posted *(url)*
* Login data -- number of key-value pairs to send -- username and
  password for example *(data)*

Example:

    -
       title: "Livejournal Friends"
       url: "http://uuu.livejournal.com/friends"
       period: 60
       extractor: livejournal
       icons:
          new: "lj-active.png"
          old: "lj-passive.png"
       login:
          url: "https://www.livejournal.com/login.bml?ret=1"
          data:
             "user": "uuu"
             "password": "ppp"

# Extractors

Extractor contains main update logic. It knows how to extract important
data from webpage and how to generate the summary.

For now there are some simple extractors:

* *plain* -- only drops HTML tags
* *sub* -- drops scripts and HTML entities also
* *lj* -- drops ads and some Livejournal special non-important markup
  data
* *livejournal* -- most thoroughly extractor for livejournal friends
  pages

# Internal design

Fetcher downloads a webpage logging in if needed. It can also check
whether there are updates available using basic HTTP properties such as
Last-Modified or (in future probably) Etag (by HEAD request).

Crawler controls fetchers. It serves the task of simultaneous download of
multiple pages. Each fetcher is run in separate thread and crawler
restarts fetchers if there are network errors. When webpage is updated at
binary level crawler pushes it to extractor.

Extractor manages history of a page. It can parse page updates and
generates update summaries. And it stores history in appropriate data
structure. As such there may be different extractors for user to choose
from. Extractors are major extensions of *livegazer*.

The rest is main program with user interface. It reads configs and
initializes modules, displays summaries, changes tray icons and routes
user interactions.

## Actions

* Initialization -- *main*
* Page download -- *crawler*
* Data extraction -- *extractor*
* Data comparison -- *extractor*
* Summary generation -- *extractor*
* User interface -- *main*

## Data

* Page history -- *extractor*
* Config -- *main*

## Threads

* Each fetcher
* Work thread (extractors)
* Main thread (UI)

# TODO

* Documentation
    * Config format
    * Comments
    * Description (user and developer)
* Translate to english
* Handsome site config (probably during program work)
* Installation procedure
* First start procedure
* Reliable configuration file loading
    * Missing config
    * Parse errors
    * Period, icons and extractor by default
    * Missing icon files

# BUGS

* `<lj-user>` links are not shown in summary

# Information

[Pango format](http://library.gnome.org/devel/pango/stable/PangoMarkupFormat.html) for `tooltip_markup`.

[Gtk::StatusIcon Description](http://ruby-gnome2.sourceforge.jp/hiki.cgi?Gtk%3A%3AStatusIcon).

# Ideas

## Configuration

Сделать более гибким формат конфигурационного файла (чтобы можно было
например указать только URL, даже без ключа `url:`).

Возможно сделать возможность указать метод логина и как передавать
сессию (cookie, get).

## Extractors

Показывать максимально удобно diff.

Можно пробовать классифицировать посты (заметка, творческий пост,
фотоотчет и т.п.). Можно просто добавлять пометки "с картинками".

Модели текста:

* Тривиальный - один текст
* Простой - массив текстов
* ЖЖ - массив (заголовков, текстов, комментариев)
* ...

All extractors run in work thread (to not block UI).

В принципе если возвращается не HTML, а например картинка, можно было бы
тоже отслеживать изменения.

Нужно как-то следить за съезжающим markup-ом, из-за которого появляются
ошибки в консоли и ничего в тултипе не отрисовывается.
Учитывая, что отображаются пользовательские данные, это особенно важно.

Можно сохранять состояние (что мы видели).

## Log

Можно писать лог всех зафиксированных состояний текстов.

Реконнекты (по любой причине) лучше писать в лог.

## User interface

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

Можно сделать отключение отслеживания поста (или по крайней мере
комментариев). Когда во френдленте пост тысячника (да и не только),
следить за каждым появляющимся комментарием обычно неинтересно.

Для ЖЖ можно было бы сделать переход по ссылке для написания
комментария.

Можно сделать добавление URL-ов online.
Так как StatusIcon не является widget-ом, можно попробовать
вытаскивать из буфера обмена адрес например по ctrl-middle-click.
Ну либо добавлять через меню.
Также удаление и отключение URL-ов.

В меню можно перечислять сайты и ставить напротив них галочки.
И можно щелкать по ним, чтобы настраивать в окошках.

Если будут окошки, то уже пригодится логотип (*livegazer*-а).

Можно вместо стандартного Tooltip показывать свое окошко, с более
продвинутой версткой.

Можно скроллингом на иконке прокручивать содержимое тултипа.

Если несколько сайтов сразу, то нужно либо несколько иконок в трее,
либо одну общую. Решил делать несколько иконок, так проще и понятнее.

Можно как-то сообщать также заодно о недоступности серверов.
Можно показывать, что непосредственно сейчас проверяются обновления.

Можно сделать указание иконок тоже URL-ом.

Можно отдельную команду (щелчком мыши) чтобы проверить новизну сразу, не
дожидаясь истечения периода.

В текущем варианте *livegazer* не приспособлен для отображения картинок
в summary, хотя можно попробовать туда поразвиваться.

## Crawler

В дальнейшем можно и RSS прикрутить, но скорее всего это лишнее,
разве что если его использовать только для отслеживания обновления.
Можно модели текстов и преобразования в модели текстов сделать
плагинами.

Each URL fetcher run in separate thread. It's easier than `select`
especially when HttpClient or similar library is used.

Возможно иногда придется делать перелогиневание.

В ЖЖ без логина есть реклама, а с логином нет (и можно по Last-Modified
отсекать).

Возможно стоит по md5 тоже проверять. Коль скоро crawler предоставляет
сервис предварительной проверки, это логично. Тем более, что Extractor
и так перегружен.

## Miscellaneous

Сделать установку через gem или как-то ещё.

Сделать описание и список доделок для github.

Придумать лицензию.

Возможно отдельный конфиг для сайтов и отдельный для настроек (например
действия при щелчке мыши).

Можно сделать вылавливание только информации с ключевыми словами или
другим образом классифицировнной как интересной.


<!--vim: set ft=mkd :-->
