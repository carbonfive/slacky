module Slacky
  class Service
    def initialize(config, bot_class)
      @config = config
      @bot_class = bot_class
    end

    def run
      puts "#{@config.name} is running"
      bot = Bot.new @config
      @bot_class.new bot
      bot.run
    end
  end
end
