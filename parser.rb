# 55 23 * * * /bin/bash -l -c 'cd /home/sol/development/li && script/runner -e production '\''Parser.new.run'\'''
#!/usr/bin/ruby

require 'sqlite3'
require 'open-uri'
require 'nokogiri'
require 'gruff'
require 'mail'

class Parser

  URL = "http://www.li.ru/rating/media/"

  def initialize
    SQLite3::Database.new 'li.sqlite3'
    @db = SQLite3::Database.open 'li.sqlite3'
    @db.execute "CREATE TABLE IF NOT EXISTS stats(time DATETIME, visits INT)"
    #@db.execute "DELETE FROM stats"
    
    @time = Time.now
  end

  def parse
    # Parsing the stats
    page = Nokogiri::HTML(open(URL))
    lenta_link = page.xpath("//a[text()='Lenta.Ru']").first
    lenta_count = lenta_link.parent.parent.xpath('td').last.text
    lenta_count = lenta_count.gsub(/\D/, '').to_i
    @db.execute "INSERT INTO stats VALUES('#{@time}', #{lenta_count})"
  end
  
  def plot
    # Preparing data
    sql = "SELECT * from STATS WHERE time > CAST('#{@time.strftime "%Y%m"}01' as datetime) ORDER BY time ASC"
    data = @db.execute(sql)
    
    points = data.map(&:last)
    labels = {}
    data.map(&:first).each_with_index do |t, i|
      time = Time.parse(t)
      labels[i] = sprintf("%02d",time.day)
    end
    
    # Plotting graph
    g = Gruff::Bar.new(2000)
    g.title = "LiveInternet - #{@time.strftime "%B %Y"}" 
    g.labels = labels
    g.data 'Lenta.Ru', points
    g.marker_font_size = 11
    g.write "graphs/#{@time.strftime "%Y-%m"}.png"
  end
  
  def log_page
    `curl --silent -o pages/#{@time.strftime "%Y-%m-%d"}.html #{URL}`
  end

  def mail_page
    filename = "pages/#{@time.strftime "%Y-%m-%d"}.html"
    title = "LiveInternet statistics for Lenta.Ru #{@time.strftime "%Y-%m-%d"}"
    addresses = [
               #'a.belonovsky@lenta-co.ru',
               #'v.kobenkova@lenta-co.ru',
               'a.lomakin@lenta-co.ru',
               'a.krasnoshchekov@lenta-co.ru'
             ]

    Mail.defaults do
      delivery_method :sendmail
      #delivery_method :smtp, address: "localhost", port: 1025
    end

    mail = Mail.new do
      from    'noreply@example.com'
      to      addresses.join(',')
      subject title
      content_type 'text/html; charset=UTF-8'
      body File.read(filename)
    end

    mail.deliver
  end

  def run
    parse
    plot
    log_page
    mail_page
  end

end

Parser.new.run
