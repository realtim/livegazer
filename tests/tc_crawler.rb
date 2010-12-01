require "../crawler"
# require "test/unit"
#  
# class TestCrawler < Test::Unit::TestCase
#  
# #  запускается перед тестами
# #  def setup
# #  end
# # 
# #  запускается после тестов
# #  def teardown
# #  end
#  
#   def test_simple
#     assert_equal(4, @num.add(2) )
#   end
#  
#   def test_simple2
#     assert_equal(4, @num.multiply(2) )
#   end
#  
# end
# 


c = Crawler.new
c.add("http://mail.ru/", 10)
c.add("http://newsru.com/", 15)
c.queue { |url, data| puts "#{url} #{data.size}" }
