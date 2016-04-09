module Slacky
  class CLI
    attr_reader :bot

    def initialize(name, opts)
      throw "CLI must be passed a name" unless name
      @options = { :verbose => false }.merge opts
      config = Config.new name
      @bot = Bot.new config
      daemon = Daemon.new config, bot
      @service = Service.new config, daemon
    end

    def run(params)
      @service.run
    end

    def start(params)
      @service.start
    end

    def stop(params)
      @service.stop
    end

    def restart(params)
      @service.restart
    end

    def status(params)
      @service.status
    end

  end
end
