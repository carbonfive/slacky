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
      first = word 0
      return false unless first
      first == @@bot.name || first == "<@#{@@bot.slack_id}>"
    end

    def command
      if @channel.type == :im
        command? ? downword(1) : downword(0)
      else
        command? ? downword(1) : nil
      end
    end

    def yes?
      [ 'y', 'yes', 'yep' ].include? @text.downcase
    end

    def no?
      [ 'n', 'no', 'nope' ].include? @text.downcase
    end

    private

    def word(n)
      return nil unless @pieces.length > n
      @pieces[n]
    end

    def downword(n)
      word(n) && word(n).downcase
    end
  end
end
