# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

RBENV_INIT = 'export PATH=/home/deployer/.rbenv/shims:/home/deployer/.rbenv/bin:$PATH;eval "$(rbenv init -)";'

every 1.day, :at => "13:44" do
  command RBENV_INIT + 'cd /home/deployer/listat/current && bundle exec ruby parser.rb >> crontab.log 2>&1'
end

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
