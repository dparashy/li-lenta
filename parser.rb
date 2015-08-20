#!/usr/bin/ruby

require 'sqlite3'
require 'open-uri'
require 'gruff'
require 'mandrill'
require 'csv'
require 'erb'
require 'yaml'

class Parser

  URL = 'http://www.liveinternet.ru/rating/media/today.tsv'
  DB_PATH = '/home/deployer/listat/'
  DB_NAME = 'li.sqlite3'

  def initialize
    dbfile = File.directory?(DB_PATH + DB_NAME) ? DB_PATH + DB_NAME : DB_NAME
    @db = SQLite3::Database.open dbfile
    @db.execute "CREATE TABLE IF NOT EXISTS stats(time DATETIME, visits INT)"
    @time = Time.now
  end

  def statistics
    i = 0
    @statistics ||= CSV.parse(open(URL), col_sep: "\t", headers: true, skip_blanks: true).map do |row|
      {
        number: i += 1,
        name: row[0],
        url: row[1],
        title: row[2],
        visitors: row[3]
      }
    end
  end

  def lenta_visitors
    statistics.find{|d| d[:name] == 'lenta.ru'}[:visitors]
  end

  def insert_stats
    @db.execute "INSERT INTO stats VALUES('#{@time}', #{lenta_visitors})"
  end

  def parse
    insert_stats
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
    file = ::ERB.new(File.read('templates/page.html.erb')).result(binding)
    File.open("pages/#{@time.strftime "%Y-%m-%d"}.html", 'w') { |f| f.write(file) }
  end

  def config
    @config ||= YAML.load_file('config/mandrill.yml')
  end

  def mail_page
    begin
      mandrill = Mandrill::API.new(config['api_key'])
      message = {
        html: File.read("pages/#{@time.strftime "%Y-%m-%d"}.html"),
        subject: "Lenta.Ru@LiveInternet #{@time.strftime "%Y-%m-%d"}",
        from_email: 'noreply-stats@lenta-co.ru',
        from_name: 'Lenta Statistics',
        to: config['to'].map { |email| { email: email, type: 'to' } }
      }
      async = false
      ip_pool = 'Main Pool'
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

    puts "#{Time.now} mailing page"
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
