#!/usr/bin/env ruby
# encoding: utf-8
require 'monitor'

# TODO: Посмотреть на синхронизацию
# Пока что засинхронизировал только изменение истории

# Преобразует страничку в структуру данных
# Умеет сравнивать структуры данных
# Умеет делать описание новостей
class PlainExtractor
   def initialize
      @history = []
      @history.extend(MonitorMixin)
      @notifier = nil
   end
   def on_change &block
      @notifier = block
   end
   def push text
      data = parse(text)
      @history.synchronize do
         if @history.empty? or @history[-1] != data
            @history << data
            @notifier.call if @notifier
         end
      end
   end
   def clear
      @history.synchronize do
         @history = [@history[0]] unless @history.empty?
      end
   end
   # TODO: возможно переименовать
   # TODO: обрезать начало
   def summary
      @history.join("\n---\n")
   end
protected
   def parse text
      text.gsub(/<[^>]*>/m, '').gsub(/^\n/, '')
   end
#   def diff
#   end
end

class SubExtractor < PlainExtractor
protected
   # Отбраковывание информации, изменение которой нам не интересно
   SUBSTITUTIONS=[
      [/<script[^>]*>(((?!<\/script>).)*)<\/script>/m, ""], #Скрипты
      [/<[^>]*>/, ' '], # Любые теги
      [/&[a-zA-Z0-9]*;/, ''], # Мета-символы
      [/\n\s*\n/, "\n"], # Пустые строки в результате
   ]
   def parse text
      data = text.dup
      SUBSTITUTIONS.each{|from,to| data.gsub!(from, to)}
      data
   end
end

class LjExtractor < SubExtractor
protected
   # Отбраковывание информации, изменение которой нам не интересно
   SUBSTITUTIONS = [
      [/<p class=['"]comments['"]>((?!<\/p>).)*<\/p>/, ''], # ЖЖ: Комментарии
      [/<strong>Tags:<\/strong>((?!<\/p>).)*<\/p>/, ''], # ЖЖ: Теги
      [/<span class=['"]subject['"]>(((?!<\/span>).)*)<\/span>/, "###i@@@\\1###/i@@@\n"], # ЖЖ: Заголовки
      [/<span style=['"]white-space: nowrap['"]>((?!<\/span>).)*<\/span>/, ''], # ЖЖ: Голосовния
      #   [/(\d\d:\d\d) ([ap]m)/, "\\1\\2"],
   ] + SUBSTITUTIONS + [
      [/ \[ Link \] /, ''], # ЖЖ: Ссылки на пост
      [/\s*\[ ссылка \]\s*/m, ' - '], # ЖЖ: Ссылки на пост
      [/.*Below are the 10 most recent friends journal entries: \[  Previous 10 entries \]/m, ''],
      [/\s*\[  Previous 10 entries \].*/m, ''],
      [/###/, "<"], # Разметка
      [/@@@/, ">"] # Разметка
   ]
   def parse text
      data = text.dup
      SUBSTITUTIONS.each{|from,to| data.gsub!(from, to)}
      data
   end
end

# Для начала (пока нет diff-а) можно хотя бы просто показывать
# только те посты, которые раньше не показывались
# Какие показывались можно определять по MD5 (хранить архив
# показанных).
class LivejournalExtractor
   DATA_MAX_SIZE=30
   def initialize
      @data = []
      @data.extend(MonitorMixin)
      @notifier = nil
      @known = []
   end
   def on_change &block
      @notifier = block
   end
   def push text
      require "digest/md5"
      data = parse(text)
      notify = false
      # Перебираем записи в обратном порядке, чтобы более старыми
      # считались те, что ниже
      data.reverse_each do |post|
         # XXX возможно достаточно сравнивать только с теми записями,
         # которые сейчас в data. И уж наверное стоит очищать @known.
         md5 = Digest::MD5.hexdigest(post.to_s)
         next if @known.include?(md5)
         @known << md5
         i = @data.find_index {|p| p["url"] == post["url"]}
         # Запомниаем время для сортировки по новизне
         post["update"] = Time.now
         @data.synchronize do
            if i
               # was: @data[i] = post
               if @data[i]["time"] != post["time"]
                  @data[i]["time"] = post["time"]
                  @data[i].delete("time_seen")
                  @data[i].delete("hide")
                  notify = true
               end
               if @data[i]["subject"] != post["subject"]
                  @data[i]["subject"] = post["subject"]
                  @data[i].delete("subject_seen")
                  @data[i].delete("hide")
                  notify = true
               end
               # TODO Дальше здесь можно сохранять text_summary в
               # отдельное поле, с разметкой для подсвечивания изменений
               if @data[i]["text"] != post["text"]
                  @data[i]["text"] = post["text"]
                  @data[i].delete("text_seen")
                  @data[i].delete("hide")
                  notify = true
               end
               if @data[i]["comments"] != post["comments"]
                  # XXX Видимо где-то все-таки проблема с синхронизацией,
                  # вылетел на следующей строчке с @data[i] == nil
                  @data[i]["comments"] = post["comments"]
                  @data[i].delete("comments_seen")
                  @data[i].delete("hide")
                  notify = true
               end
               # XXX
               raise "Debug exception. This shouldn't happen.\nknown: #{@data[i]}\npost: #{post}" unless notify
               @data[i]["update"] = post["update"]
            else
               @data << post
               notify = true
            end
         end
      end
      @notifier.call if notify
   end
   def clear
      @data.synchronize do
         @data.each do |post|
            post["hide"] = true
            post["time_seen"] = true
            post["subject_seen"] = true
            post["text_seen"] = true
            post["comments_seen"] = true
         end
         # Чтобы не хранить посты вечно
         # TODO Возможно подчищать надо не только тут
         @data = @data[@data.size-DATA_MAX_SIZE..@data.size-1] if @data.size > DATA_MAX_SIZE
      end
   end
   def summary
      # Показываются только обновленные посты, более новые снизу
      @data.select{|post| !post["hide"]}.sort{|a, b| a["update"] <=> b["update"]}.map do |post|
         "#{gray_if(post["time_seen"]){ post["time"] }}\n"\
         "#{green{ "<i>#{post["subuser"].empty? ? post["user"] : "#{post["subuser"]} [#{post["user"]}]"}</i>" }}"\
         " #{gray_if(post["subject_seen"]){ "<b>#{post["subject"]}</b>" }}\n"\
         "#{post["text_seen"] ? gray{ truncate(100){ post["text"] }} : truncate(256){ post["text"] }}"\
         "#{gray_if(post["comments_seen"]){ "\n{#{post["comments"]}}" } if post["comments"]}"
      end.join("\n\n")
   end
protected
   # Summary
   def truncate len
      str = yield
      str = str[0...len].sub(/ [^ ]*$/, '') + " ..." if str.size > len
      str
   end
   def green
      "<span fgcolor=\"#007000\">#{yield}</span>"
   end
   def gray
      "<span fgcolor=\"#777777\">#{yield}</span>"
   end
   def gray_if test
      if test
         gray{ yield }
      else
         yield
      end
   end
   # Парсинг
   def flatten str
      str.gsub(/<[^>]*>/, ' ').gsub(/&amp;/, '&').gsub(/&[a-zA-Z0-9]*;/, '').gsub(/&/, '&amp;').gsub(/\n/, ' ').squeeze(" ")
   end
   def parse text
      require 'hpricot'
      doc = Hpricot(text)
      posts = doc/"td.entry"/".."
      result = []
      posts.each do |post|
         result << {
            "url" => (post/"td.metabar/p/a").first["href"],
            "time" => (post/"td.metabar/em").inner_html.force_encoding("utf-8"),
            "user" => (post/"td.metabar/strong/a").inner_html.force_encoding("utf-8"),
            "subuser" => (post/"td.metabar/a").inner_html.force_encoding("utf-8"),
            "subject" => flatten((post/"td.entry/span.subject/a").inner_html.force_encoding("utf-8")),
            "text" => flatten((post/"td.entry").inner_html.force_encoding("utf-8").
                      gsub((post/"td.entry/span").first.to_s.force_encoding("utf-8"), '').
                      gsub((post/"td.entry//p.comments").last.to_s.force_encoding("utf-8"), '').
                      gsub(/<a [^>]*href[^>]*>/im, ' @').
                      gsub(/<img [^>]*>/im, ' [IMG] ')),
            "comments" => (post/"td.entry//p.comments/a").first["href"].force_encoding("utf-8").scan(/nc=(\d+)/).flatten[0]
         }
      end
      result
   end
end
