require 'yaml'
require 'time'
require 'pg'
require 'dotenv'

module Slacky
  class Config
    attr_reader :name, :db

    def initialize(name, opts = {})
      @name = name
      Dotenv.load ".env", "#{config_dir}/.env"
      FileUtils.mkdir config_dir unless File.directory? config_dir
      User.config = self
    end

    def db
      db = PG.connect db_connect_params
      db.exec 'set client_min_messages = warning'
      db
    rescue => e
      if e.message =~ /does not exist/
        puts
        puts "ERROR - database does not exist: #{db_connect_params}"
      end
      raise e
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

    def whitelist_users
      return nil unless ENV['WHITELIST_USERS']
      ENV['WHITELIST_USERS'].split(',').map {|u| u.strip}
    end

    private

    def db_connect_params
      ENV['DATABASE_URL'] || { dbname: "slacky_#{down_name}" }
    end
  end
end
