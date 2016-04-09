require 'yaml'
require 'time'
require 'pg'

class Slacky::Config
  attr_reader :config, :pid_file, :name

  def initialize(name, opts = {})
    @name = name
    @dir = opts[:config_dir] || "#{ENV['HOME']}/.#{down_name}"
    FileUtils.mkdir @dir unless File.directory? @dir
    @pid_file = "#{@dir}/pid"
    @db = init_db
    Parky::User.db = @db

    @timestamps = {}
    load_config :force => true
  end

  def down_name
    @name.downcase
  end

  def init_db
    conn = PG.connect dbname: "slackbot_#{down_name}"
    conn.exec <<-SQL
create if not exists users (
  slack_id     varchar(20),
  slack_im_id  varchar(20),
  timezone     varchar(20),
  data         jsonb
);
SQL
    conn
  end

  def slack_api_token
    @config[:slack_api_token]
  end

  def slack_reject_channels
    @config.fetch(:slack_reject_channels, '').split ','
  end

  def slack_accept_channels
    @config.fetch(:slack_accept_channels, '').split ','
  end

  def slackbot_id
    @config[:slack_bot_id]
  end

  def reload(options = {})
    options = { :force => false }.merge options
    load_config options
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

  def load_config(options)
    @config = if_updated? config_file, options do
      YAML.load( IO.read(config_file) )
    end
    @config ||= {}
  end

  def config_file
    "#{@dir}/config.yml"
  end

  def log_file
    "#{@dir}/#{down_name}.log"
  end

  def if_updated?(file_name, options)
    return nil if ! File.exists? file_name

    file = File.new file_name
    last_read = @timestamps[file_name]
    stamp = file.mtime
    if options[:force] || last_read.nil? || stamp > last_read
      yield
    else
      nil
    end
  end
end
