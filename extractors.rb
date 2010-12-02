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
      data.each do |post|
         md5 = Digest::MD5.hexdigest(post.to_s)
         next if @known.include?(md5)
         unless notify
            @data.synchronize do
               @data.each do |p|
                  p["time_seen"] = true
                  p["subject_seen"] = true
                  p["text_seen"] = true
                  p["comments_seen"] = true
               end
            end
         end
         notify = true
         @known << md5
         i = @data.find_index {|p| p["url"] == post["url"]}
         @data.synchronize do
            if i
               # was: data[i] = post
               @data[i].delete("hide")
               if @data[i]["time"] != post["time"]
                  @data[i]["time"] = post["time"]
                  @data[i].delete("time_seen")
               end
               if @data[i]["subject"] != post["subject"]
                  @data[i]["subject"] = post["subject"]
                  @data[i].delete("subject_seen")
               end
               if @data[i]["text"] != post["text"]
                  @data[i]["text"] = post["text"]
                  @data[i].delete("text_seen")
               end
               if @data[i]["comments"] != post["comments"]
                  @data[i]["comments"] = post["comments"]
                  @data[i].delete("comments_seen")
               end
            else
               @data << post
            end
         end
      end
      @notifier.call if notify
   end
   def clear
      @data.synchronize do
         @data.each do |post|
            post["hide"] = true
         end
         # Чтобы не хранить посты вечно
         # TODO Возможно подчищать надо не только тут
         @data = @data[@data.size-DATA_MAX_SIZE..@data.size-1] if @data.size > DATA_MAX_SIZE
      end
   end
   def summary
      @data.select{|post| !post["hide"]}.map do |post|
         "#{post["time_seen"] ? "<span fgcolor=\"#777777\">" : ""}#{post["time"]}#{post["time_seen"] ? "</span>" : ""}\n"\
         "<span fgcolor=\"#007000\"><i>#{post["user"]}</i></span>"\
         " #{post["subject_seen"] ? "<span fgcolor=\"#777777\">" : ""}<b>#{post["subject"]}</b>#{post["subject_seen"] ? "</span>" : ""}\n"\
         "#{post["text_seen"] ? "<span fgcolor=\"#777777\">" : ""}#{post["text"]}#{post["text_seen"] ? "</span>" : ""}"\
         "#{post["comments"] ? (post["comments_seen"] ? "\n<span fgcolor=\"#777777\">{#{post["comments"]}}</span>" : "\n{#{post["comments"]}}") : ""}"
      end.join("\n\n")
   end
protected
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
            "subject" => (post/"td.entry/span.subject/a").inner_html.force_encoding("utf-8"),
            "text" => (post/"td.entry").inner_html.force_encoding("utf-8").
                      gsub((post/"td.entry/span").first.to_s.force_encoding("utf-8"), '').
                      gsub((post/"td.entry/p.comments").last.to_s.force_encoding("utf-8"), '').
                      gsub(/<a [^>]*href[^>]*>/im, '@').
                      gsub(/<img [^>]*>/im, '[IMG]').
                      gsub(/<[^>]*>/, ' ').
                      gsub(/&[a-zA-Z0-9]*;/, '').
                      gsub(/\n/, ' ').
                      squeeze(" "),
            "comments" => (post/"td.entry/p.comments/a").first["href"].force_encoding("utf-8").scan(/nc=(\d+)/).flatten[0]
         }
      end
      result
   end
end
