require 'yaml'
require 'time'
require 'pg'
require 'dotenv'

module Slacky
  class Config
    attr_reader :pid_file, :name, :db

    def initialize(name, opts = {})
      @name = name
      Dotenv.load ".env", "#{config_dir}/.env"
      FileUtils.mkdir config_dir unless File.directory? config_dir
      @pid_file = "#{config_dir}/pid"
      @timestamps = {}
      User.config = self
    end

    def db
      db = PG.connect db_connect_params
      db.exec 'set client_min_messages = warning'
      db
    end

    def down_name
      @name.downcase
    end

    def slack_api_token
      ENV['SLACK_API_TOKEN']
    end

    def config_dir
      ENV['CONFIG_DIR'] || "#{ENV['HOME']}/.#{down_name}"
    end

    def slack_reject_channels
      return nil unless ENV['REJECT_CHANNELS']
      ENV['REJECT_CHANNELS'].split(',').map {|c| c.strip}
    end

    def slack_accept_channels
      return nil unless ENV['ACCEPT_CHANNELS']
      ENV['ACCEPT_CHANNELS'].split(',').map {|c| c.strip}
    end

    def log(msg, ex = nil)
      log = File.new(log_file, 'a')
      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      type = ex ? 'ERROR' : ' INFO'
      log.puts "#{type}  #{timestamp}  #{msg}"
      if ex
        log.puts ex.message
        log.puts("Stacktrace:\n" + ex.backtrace.join("\n"))
      end
      log.flush
    end

    private

    def db_connect_params
      ENV['DATABASE_URL'] || { dbname: "slacky_#{down_name}" }
    end

    def log_file
      "#{config_dir}/#{down_name}.log"
    end
  end
end
