require "../crawler"
require "digest/md5"
require "test/unit"

class TestFetcher < Test::Unit::TestCase

   def test_connection
      fetcher = Fetcher.new "http://www.ya.ru/"
      assert_not_nil(fetcher.get)
   end

   def test_simple_fetch
      fetcher = Fetcher.new "http://www.gnu.org/licenses/gpl-1.0.txt"
      text = fetcher.get
      md5 = Digest::MD5.hexdigest(text)
      assert_equal("5b122a36d0f6dc55279a0ebc69f3c60b", md5)
   end

   # TODO Сделать проверки для сайтов других кодировок
   def test_utf_fetch
      fetcher = Fetcher.new "http://www.ya.ru/"
      assert_equal("UTF-8", fetcher.get.encoding.to_s)
   end

   def test_image_fetch
      fetcher = Fetcher.new "http://www.cs.cmu.edu/~chuck/lennapg/lena_std.tif"
      text = fetcher.get
      md5 = Digest::MD5.hexdigest(text)
      assert_equal("7278246cf26b76e0ca398e7f739b527e", md5)
   end

   def test_changed
      fetcher = Fetcher.new "http://www.gnu.org/licenses/gpl-1.0.txt"
      assert_equal(true, fetcher.changed?)
      first_text = fetcher.get
      md5 = Digest::MD5.hexdigest(first_text)
      assert_equal("5b122a36d0f6dc55279a0ebc69f3c60b", md5)
      assert_equal(false, fetcher.changed?)
      second_text = fetcher.get
      assert_equal(first_text, second_text)
   end

   def test_invalid_url
      fetcher = Fetcher.new "http://www.gnu.org/licenses/gpl-1.0txt"
      assert_nil(fetcher.get)
   end

   def test_no_login
      fetcher = Fetcher.new "http://demo.silverstripe.com/admin/"
      assert_no_match(/Page Version History/, fetcher.get)
   end

   def test_login
      fetcher = Fetcher.new "http://demo.silverstripe.com/admin/",
                     "url" => "http://demo.silverstripe.com/Security/LoginForm",
                     "data" => {
                        "AuthenticationMethod" => "UsernameAuthenticator",
                        "BackURL" => "/admin/",
                        "Password" => "password",
                        "Username" => "admin",
                        "action_dologin" => "Log in"
                     }
      text = fetcher.get
      File.open("text", "w"){|f| f.write(text)}
      assert_match(/Page Version History/, text)
   end

## TODO
#   def test_no_ssl_login
#   end
#   def test_ssl_login
#      fetcher = Fetcher.new "https://demo.service-now.com/navpage.do",
#                     "url" => "https://demo.service-now.com/login.do",
#                     "data" => {
#                        "user_name" => "admin",
#                        "user_password" => "admin",
#                        "ni.nolog.user_password" => "true",
#                        "ni.noecho.user_name" => "true",
#                        "ni.noecho.user_password" => "true",
#                        "language_select" => "en",
#                        "remember_me" => "true",
#                        "screensize" => "1920x1080",
#                        "sys_action" => "sysverb_login",
#                        "not_important" => ""
#                     }
#      fetcher = Fetcher.new "https://demo.phppointofsale.com/index.php/home",
#                     "url" => "https://demo.phppointofsale.com/index.php/login",
#                     "data" => {
#                        "username" => "admin",
#                        "password" => "pointofsale",
#                        "loginButton" => "Go"
#                     }
#      puts fetcher.get
#   end
end

