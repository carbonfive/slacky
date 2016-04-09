module Slacky

  class CLI
    def initialize(name, opts)
      throw "CLI must be passed a name" unless name
      @options = { :verbose => false }.merge opts
      config = Config.new name
      daemon = Daemon.new(config)
      @service = Service.new(config, daemon)
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
