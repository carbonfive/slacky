module Slacky
  class Channel
    attr_reader :slack_id, :name, :topic, :purpose, :members, :type

    @@channels = {}
    @@bot = nil

    def self.bot=(bot)
      @@bot = bot
    end

    def self.find(channel)
      return channel.map { |c| Channel.find c } if channel.is_a? Array
      return channel if channel.is_a? Channel
      @@channels[channel]
    end

    def self.im(channel_id, user)
      Channel.new.populate_im(channel_id, user).save
    end

    def self.channel(channel_data)
      Channel.new.populate_channel(channel_data).save
    end

    def self.group(group_data)
      Channel.new.populate_group(group_data).save
    end

    def archived?
      @archived
    end

    def member?
      case @type
      when :channel ; @member
      when :group   ; @members[@@bot.slack_id]
      when :im      ; true
      else            throw "Unknown channel type: #{@type}"
      end
    end

    def save
      @@channels[@slack_id] = self
      @@channels["##{@name}"] = self if @name
      @@channels["@#{@user.username}"] = self if @user
      self
    end

    def populate_channel(channel)
      populate channel
      @type   = :channel
      @member = channel.is_member
      self
    end

    def populate_group(group)
      populate group
      @type     = :group
      @members  = User.find group.members
      self
    end

    def populate_im(slack_id, user)
      @type     = :im
      @slack_id = slack_id
      @user     = user
      self
    end

    private

    def populate(channel)
      @slack_id = channel.id
      @name     = channel.name
      @archived = channel.is_archived
      @topic    = channel.topic.value
      @purpose  = channel.purpose.value
    end
  end
end
