#!/usr/bin/ruby

require 'sqlite3'
require 'open-uri'
require 'nokogiri'
require 'gruff'
require 'mandrill'

class Parser

  URL = "http://www.li.ru/rating/media/"
  DB_PATH = '/home/deployer/listat/'
  DB_NAME = 'li.sqlite3'

  def initialize
    dbfile = File.directory?(DB_PATH + DB_NAME) ? DB_PATH + DB_NAME : DB_NAME
    @db = SQLite3::Database.open dbfile
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
    begin
      mandrill = Mandrill::API.new '8Xx06y45dEkqk1wJMdUilg'
      message = {
        "html" => File.read("pages/#{@time.strftime "%Y-%m-%d"}.html"),
        "subject" => "Lenta.Ru@LiveInternet #{@time.strftime "%Y-%m-%d"}",
        "from_email" => "noreply-stats@lenta-co.ru",
        "from_name" => "Lenta Statistics",
        "to" =>
           [
             {"email"=>"a.goreslavskiy@lenta-co.ru", "type"=>"to"},
             {"email"=>"a.ryazantsev@lenta-co.ru", "type"=>"to"},
             {"email"=>"a.belonovsky@lenta-co.ru", "type"=>"to"},
             {"email"=>"p.kamenchenko@lenta-co.ru", "type"=>"to"},
             {"email"=>"v.kobenkova@lenta-co.ru", "type"=>"to"},
             {"email"=>"a.gladkov@lenta-co.ru", "type"=>"to"},
             {"email"=>"a.lomakin@lenta-co.ru", "type"=>"to"},
             {"email"=>"n.morozov@lenta-co.ru", "type"=>"to"},
             {"email"=>"d.parashy@lenta-co.ru", "type"=>"to"},
             {"email"=>"a.krasnoshchekov@lenta-co.ru", "type"=>"to"}
           ]
      }
      async = false
      ip_pool = "Main Pool"
      send_at = nil
      result = mandrill.messages.send message, async, ip_pool, send_at
      p result
    rescue Mandrill::Error => e
        puts "A mandrill error occurred: #{e.class} - #{e.message}"
        raise
    end
  end

  def run
    puts '='*20

    puts "#{Time.now} logging page"
    log_page

    puts "#{Time.now} mailing  page"
    mail_page

    puts "#{Time.now} parsing page"
    parse

    puts "#{Time.now} plotting graphic"
    plot

    puts "#{Time.now} all done"
    @db.close
  end

end

Parser.new.run
