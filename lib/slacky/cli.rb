module Slacky
  class CLI
    attr_reader :bot

    def initialize(name, bot_class, opts)
      raise "CLI must be passed a name" unless name
      config = Config.new name
      @service = Service.new config, bot_class
    end

    def run(params)
      @service.run
    end
  end
end
