require 'async'
require 'parse-cron'

module Slacky
  class Cronner
    def self.schedule(cron_string, &blk)
      cron_parser = CronParser.new(cron_string)
      next_time = cron_parser.next(Time.now)
      Async do |task|
        task.sleep next_time - Time.now
        result = yield next_time
        schedule(cron_string, &blk) unless result == :stop
      end
    end
  end
end
