# encoding: utf-8
require "../extractors"
require "digest/md5"
require "test/unit"

class TestFetcher < Test::Unit::TestCase

   HISTORY = [
      "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">"\
      "\n<html>\n<head>\n  <title>Test web site</title>\n</head>\n<body"\
      "\n style=\"color: rgb(0, 0, 0); background-color: rgb(245, 204, 176);"\
      " background-image: url(./images/back.jpg);\"\n alink=\"#db70db\""\
      " link=\"red\" vlink=\"#2f2f4f\">\n<h1>Hello!</h1>\n</body>\n</html>\n",
      "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">"\
      "\n<html>\n<head>\n  <title>Test web site</title>\n</head>\n<body"\
      "\n style=\"color: rgb(0, 0, 0); background-color: rgb(245, 204, 176);"\
      " background-image: url(./images/back.jpg);\"\n alink=\"#db70db\""\
      " link=\"red\" vlink=\"#2f2f4f\">\n<h1>Hello!</h1>\n<p>\n<b>News!</b>"\
      " I've aded news to my page.\n</p>\n</body>\n</html>\n"
   ]

   def test_push
      extractor = PlainExtractor.new
      assert(extractor.to_s.empty?)
      extractor.push HISTORY[0]
      assert(!extractor.to_s.empty?)
   end

   def test_clean
      extractor = PlainExtractor.new
      assert(extractor.to_s.empty?)
      extractor.push HISTORY[0]
      assert(!extractor.to_s.empty?)
      extractor.clean
      assert(extractor.to_s.empty?)
   end

   def test_changes
      extractor = PlainExtractor.new
      change_count = 0
      extractor.on_change { change_count += 1 }
      assert_equal(0, change_count)
      extractor.push HISTORY[0]
      assert_equal(1, change_count)
      extractor.push HISTORY[1]
      assert_equal(2, change_count)
      extractor.push HISTORY[1]
      assert_equal(2, change_count)
      extractor.to_s # Проверяем, что не вызывает изменений
      assert_equal(2, change_count)
      extractor.clean
      assert_equal(2, change_count)
      extractor.to_s # Проверяем, что не вызывает изменений
      assert_equal(2, change_count)
   end

   # TODO: когда выработается формат, нужно сделать проверку to_s
   # TODO: change + to_s

end
