require "selenium-webdriver"
require 'pry'
require 'net/http'
require 'fileutils'
require 'zip'

base_url = 'https://shdev.preview.saleshood.com'
username = '*****'
password = '*****'
artwork_folder = 'artworks'
zip_folder = 'artworks.zip'

options = Selenium::WebDriver::Chrome::Options.new(args: ['headless'])
driver = Selenium::WebDriver.for :chrome, options: options
wait = Selenium::WebDriver::Wait.new(:timeout => 10)

driver.get("#{base_url}/auth/login")

puts "Logging in as #{username}"

eUsr = driver.find_element(id: 'user_login')
eUsr.send_keys username
ePwd = driver.find_element(id: 'user_password')
ePwd.send_keys password
bSubmit = driver.find_element(class: 'btn-login')
bSubmit.click

wait.until { driver.find_element(class: 'ant-layout-header') }

cookie_keys = ['CloudFront-Signature', 'CloudFront-Policy', 'CloudFront-Key-Pair-Id']
cookies = driver.manage.all_cookies
cookies_map = {}
cookies.each do |c|
  if cookie_keys.include?(c[:name])
    cookies_map[c[:name]] = c[:value]
  end
end
cookie_string = ''
cookies_map.each do |k, v|
  cookie_string += "#{k}=#{v}; "
end

if Dir.exist?("./#{artwork_folder}")
  FileUtils.remove_dir("./#{artwork_folder}")
end
Dir.mkdir("./#{artwork_folder}")

puts "Downloading Library artworks"

driver.get "#{base_url}/library"
wait.until { driver.find_element class: 'huddle-category' }
eCategories = driver.find_elements class: 'huddle-category'
category_artworks = []
eCategories.each do |e|
  category_artworks.push e.attribute('src')
end

if Dir.exist?("./#{artwork_folder}/library")
  FileUtils.remove_dir("./#{artwork_folder}/library")
end
Dir.mkdir("./#{artwork_folder}/library")

category_artworks.each do |aw|
  uri = URI(aw)
  req = Net::HTTP::Get.new(uri)
  req['Cookie'] = cookie_string
  req['Host'] = 'content.preview.saleshood.com'

  http = Net::HTTP.new(uri.hostname, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  name = aw.split('/')[-1]
  res = http.request(req)
  File.open("./#{artwork_folder}/library/#{name}", "wb") do |f|
    f.write res.body
  end
end

puts "Downloading Huddle artworks"

driver.get "#{base_url}/huddle_publishers"
wait.until { driver.find_element class: 'imgCotent' }
eHuddles = driver.find_elements class: 'imgCotent'
huddle_artworks = []
eHuddles.each do |eHuddle|
  img = eHuddle.find_element(xpath: 'img')
  huddle_artworks.push img.attribute('src')
end

if Dir.exist?("./#{artwork_folder}/huddle")
  FileUtils.remove_dir("./#{artwork_folder}/huddle")
end
Dir.mkdir("./#{artwork_folder}/huddle")

huddle_artworks.first(20).each do |ha|
  uri = URI(ha)
  req = Net::HTTP::Get.new(uri)
  req['Cookie'] = cookie_string
  req['Host'] = 'content.preview.saleshood.com'

  http = Net::HTTP.new(uri.hostname, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  name = ha.split('/')[-1]
  res = http.request(req)
  File.open("./#{artwork_folder}/huddle/#{name}", "wb") do |f|
    f.write res.body
  end
end

Zip::File.open("./#{zip_folder}", Zip::File::CREATE) do |zf|
  Dir[File.join("./#{artwork_folder}", "**", "**")].each do |f|
    zf.add(f.sub("./#{artwork_folder}/", ""), f)
  end
end

driver.quit

