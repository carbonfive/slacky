require 'fileutils'

class Slacky::Service
  def initialize(config, daemon)
    @config = config
    @daemon = daemon
  end

  def run
    @daemon.start false
  end

  def start(persist = false)
    pid = get_pid
    if pid
      puts "#{@config.name} is already running with PID #{pid}"
      return
    end

    print "Starting #{@config.name}... "
    new_pid = Process.fork { @daemon.start }
    Process.detach new_pid
    puts "started"
  end

  def stop(persist = false)
    pid = get_pid
    unless pid
      puts "#{@config.name} is not running"
      return
    end

    print "Stopping #{@config.name}..."

    begin
      Process.kill 'HUP', pid
    rescue
      @daemon.cleanup
    end

    ticks = 0
    while pid = get_pid && ticks < 40
      sleep 0.5
      ticks += 1
      print '.' if ticks % 4 == 0
    end
    puts " #{pid.nil? ? 'stopped' : 'failed'}"
  end

  def restart
    stop
    start
  end

  def status
    pid = get_pid
    if pid
      puts "#{@config.name} is running with PID #{pid}"
      true
    else
      puts "#{@config.name} is not running"
      false
    end
  end

  private

  def get_pid
    return nil unless File.exists? @config.pid_file
    IO.read(@config.pid_file).to_i
  end

end
