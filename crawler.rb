#!/usr/bin/ruby
# encoding: utf-8
require 'httpclient'

### ЖЖ
# ETag / If-None-Match не работают, ETag всё время меняется
# Last-Modified / If-Modified-Since не работают видимо потому, что
#    If-Modified-Since не отрабатывает на сервере
# Зато head вполне позволяет не качать всю страницу
# Keep-Alive похоже есть (по tcpdump не проверял, но по логам похоже)
# Всякие accept, user-agent и т.п. вроде не нужны


# TODO: продумать обработку ошибок и возврат соответствующего статуса
# XXX: обработка кодировок

# Может работать одновременно в нескольких нитях
class Fetcher
   REDIRECT_LIMIT = 10
   def initialize url, opts = nil
      @url = url
      @login = opts
      @c = HTTPClient.new
      #@c.debug_dev = file
      login
   end
   def login
      if @login
         raise "Нет login/url" unless @login.has_key?("url")
         @c.post(@login["url"], @login["data"])
      end
   end
   def changed?
      if @last
         r = redirect_loop{|url| @c.head(url)}
         return r.status == 200 && r.header["Last-Modified"][0] != @last
      end
      return true
   end
   def get
      r = redirect_loop{|url| @c.get(url)}
      if r.status == 200
         @last = r.header["Last-Modified"][0]
         return r.content.force_encoding("utf-8") # XXX FIXME Нужно обрабатывать кодировку аккуратнее
      end
      nil
   end
private
   # Цикл повторного запуска запроса при редиректах
   # Передает в блок тест URL-а для запроса
   # Блок должен возвращать результат запроса
   def redirect_loop
      url = URI.parse(@url)
      r = yield(url.to_s)
      while r.status == 302
         newurl = URI.parse(r.header['Location'][0])
         newurl = url + newurl unless newurl.is_a?(URI::HTTP)
         url = newurl
         r = yield(url.to_s)
      end
      r
   end
end


# Очередь обновленных страниц
#
# Интерфейс управления скачиванием URL-ов
# Все публичные методы класса вызываются в нити, занимающейся обработкой данных
# URL является идентификатором, поэтому нельзя два раза использовать
# один URL
# Скачивание каждого URL-а запускает в отдельной нити, хотя это уже
# подробности реализации

# TODO Обработка ошибок и т.п.
class Crawler
   def initialize
      @fetchers = {}
      @queue = []
      @queue_mutex = Mutex.new
      @queue_cond = ConditionVariable.new
   end
   # url
   # period
   # [login = { :url, :method, :data => {"key" => "value" ...}}]
   def add url, period = 60, opts = nil
      @fetchers[url] = Thread.new do
         begin
            f = Fetcher.new url, opts

            loop do
               if f.changed?
                  text = f.get
                  unless text.nil?
                     @queue_mutex.synchronize do
                        @queue.push([url, text])
                        @queue_cond.signal
                     end
                  end
               end
               sleep period
            end
         rescue
            puts "Fetcher [#{url}] error: #$!\n#{$!.backtrace.join("\n")}"
            puts "Retrying..."
            retry
         end
      end
   end
   # url
   def del url
      @fetchers.delete(url).kill
   end
   # callback for new docs
   def queue
      loop do
         @queue_mutex.synchronize do
            @queue_cond.wait(@queue_mutex)
            yield *@queue.pop
         end
      end
   end
end
