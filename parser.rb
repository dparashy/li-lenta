# 55 23 * * * /bin/bash -l -c 'cd /home/sol/development/li && script/runner -e production '\''Parser.new.run'\'''
#!/usr/bin/ruby

require 'sqlite3'
require 'open-uri'
require 'nokogiri'
require 'gruff'

class Parser

  def initialize
    SQLite3::Database.new 'li.sqlite3'
    @db = SQLite3::Database.open 'li.sqlite3'
    @db.execute "CREATE TABLE IF NOT EXISTS stats(time DATETIME, visits INT)"
    #@db.execute "DELETE FROM stats"
  end

  def parse
    # Parsing the stats
    page = Nokogiri::HTML(open("http://www.li.ru/rating/media/"))
    lenta_link = page.xpath("//a[text()='Lenta.Ru']").first
    lenta_count = lenta_link.parent.parent.xpath('td').last.text
    lenta_count = lenta_count.gsub(/\D/, '').to_i
    @db.execute "INSERT INTO stats VALUES('#{Time.now}', #{lenta_count})"
  end
  
  def plot
    # Preparing data
    sql = "SELECT * from STATS WHERE time > CAST('#{sprintf("%02d%02d", Time.now.year, Time.now.month)}01' as datetime) ORDER BY time ASC"
    data = @db.execute(sql)
    
    points = data.map(&:last)
    labels = {}
    data.map(&:first).each_with_index do |t, i|
      time = Time.parse(t)
      labels[i] = sprintf("%02d",time.day)
    end
    
    # Plotting graph
    g = Gruff::Bar.new(2000)
    g.title = "LiveInternet - #{Date::MONTHNAMES[Date.today.month]} #{Time.now.year}" 
    g.labels = labels
    g.data 'Lenta.Ru', points
    g.marker_font_size = 11
    g.write sprintf("graphs/%d-%02d.png", Time.now.year, Time.now.month)
  end
  
  def run
    parse
    plot
  end

end

Parser.new.run
