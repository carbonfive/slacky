module Slacky
  class Message
    attr_reader :raw, :text, :user, :channel

    @@decorator = @@bot = nil

    def self.decorator=(decorator)
      @@decorator = decorator
    end

    def self.bot=(bot)
      @@bot = bot
    end

    def initialize(user, channel, raw)
      @raw = raw
      @user = user
      @channel = channel
      @text = raw.text.strip
      @pieces = @text.split ' '
      self.extend @@decorator if @@decorator
    end

    def reply(msg)
      @@bot.client.message channel: @channel.slack_id, reply_to: @raw.id, text: msg
    end

    def command?
      @pieces.length > 0 && @pieces[0] == @@bot.name
    end

    def command
      if @channel.type == :im
        @pieces.length > 0 && @pieces[0].downcase
      else
        return nil unless command?
        @pieces.length > 1 && @pieces[1].downcase
      end
    end

    def yes?
      [ 'y', 'yes' ].include? @text
    end

    def no?
      [ 'n', 'no' ].include? @text
    end
  end
end
