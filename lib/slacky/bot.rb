require 'slack-ruby-client'
require 'set'
require 'tzinfo'
require 'em/cron'

module Slacky
  class Bot
    attr_reader :client, :config, :slack_id

    def initialize(config)
      config.log "#{config.name} is starting up..."
      puts "#{config.name} is starting up..."

      @config = config
      @command_handlers = []
      @channel_handlers = []
      @im_handlers = []
      @raw_handlers = []
      @cron_handlers = []

      unless @config.slack_api_token
        @config.log "No Slack API token found.  Use environment variable SLACK_API_TOKEN."
        return
      end

      Slack.configure do |slack_cfg|
        slack_cfg.token = @config.slack_api_token
      end

      @client = Slack::RealTime::Client.new

      auth = web_client.auth_test
      if auth.ok
        @slack_id = auth.user_id
        @config.log "Slackbot is active!"
      else
        @config.log "Slackbot is doomed :-("
        return
      end

      @bookkeeper = Bookkeeper.new @client

      Channel.bot = self
      Message.bot = self

      populate_users
      populate_channels
      stay_alive

    end

    def web_client
      @client.web_client
    end

    def name
      @config.down_name
    end

    def known_commands
      @command_handlers.map { |ch| ch[:command] }
    end

    def on(type, &block)
      @raw_handlers << { type: type, handler: block }
    end

    def on_command(command, &block)
      @command_handlers << { command: command.downcase, handler: block }
    end

    def on_message(attrs, &block)
      attrs ||= {}
      @channel_handlers << { match: attrs[:match], channels: attrs[:channels], handler: block }
    end

    def on_im(attrs, &block)
      attrs ||= {}
      @im_handlers << { match: attrs[:match], handler: block }
    end

    def at(cron, &block)
      @cron_handlers << { cron: cron, handler: block }
    end

    def handle_channel(message)
      handled = false

      if message.command?
        @command_handlers.each do |h|
          command, handler = h.values_at :command, :handler
          next unless command == message.command
          handler.call message
          handled = true
        end
      end

      return if handled

      @channel_handlers.each do |h|
        match, channels, handler = h.values_at :match, :channels, :handler
        accept = Channel.find channels
        next if accept && ! accept.include?(message.channel)
        next if match && ! match === message
        handler.call message
      end
    end

    def handle_im(message)
      unless message.user.slack_im_id == message.channel.slack_id
        message.user.slack_im_id = message.channel.slack_id
        message.user.save
      end

      handled = false

      @command_handlers.each do |h|
        command, handler = h.values_at :command, :handler
        next unless command == message.command
        handler.call message
        handled = true
      end

      return if handled

      @im_handlers.each do |h|
        match, handler = h.values_at :match, :handler
        next if match && ! match === message
        handler.call message
      end
    end

    def run
      @bookkeeper.keep_the_books

      @client.on :message do |data|
        next unless ( user = User.find data.user )
        next unless user.valid?

        channel = Channel.find data.channel
        channel = Channel.im data.channel, user if data.channel =~ /^D/ && ! channel
        next unless channel

        reject = Channel.find @config.slack_reject_channels
        next if reject && reject.find { |c| c.slack_id == data.channel }

        accept = Channel.find @config.slack_accept_channels
        next if accept && ! accept.find { |c| c.slack_id == data.channel }

        message = Message.new(user, channel, data)
        handle_channel message if [ :group, :channel ].include? channel.type
        handle_im      message if [ :im              ].include? channel.type
      end

      @raw_handlers.each do |h|
        type, handler = h.values_at :type, :handler
        @client.on type do |data|
          handler.call data
        end
      end

      Thread.abort_on_exception = true
      @cron_thread ||= Thread.new do
        EM.run do
          @cron_handlers.each do |h|
            cron, handler = h.values_at :cron, :handler
            EM::Cron.schedule cron do |time|
              handler.call
            end
          end
        end
      end

      puts "#{@config.name} is listening to: #{@config.slack_accept_channels}"

      @client.start!
    end

    def populate_users
      print "Getting users from Slack..."
      resp = web_client.users_list presence: 1
      throw resp unless resp.ok
      User.invalidate_all_users
      whitelist = @config.whitelist_users || []
      resp.members.map do |member|
        next unless member.profile.email # no bots
        next if member.deleted # no ghosts
        unless whitelist.include?(member.id) || whitelist.include?(member.name) || whitelist.include?("@#{member.name}")
          next if member.is_ultra_restricted # no single channel guests
          next if member.is_restricted # no multi channel guests either
        end
        user = User.find(member.id) || User.new(slack_id: member.id)
        user.populate(member).validate.save
      end
      puts " done!"
    rescue => e
      puts " error: #{e.message}"
      raise e
    end

    def populate_channels
      print "Getting channels from Slack..."
      resp = web_client.channels_list
      throw resp unless resp.ok
      resp.channels.map do |channel|
        Channel.channel channel
      end

      resp = web_client.groups_list
      throw resp unless resp.ok
      resp.groups.map do |group|
        Channel.group group
      end
      puts " done!"
    rescue => e
      puts " error: #{e.message}"
      raise e
    end

    def stay_alive
      at '* * * * *' do
        @client.pingg stamp: Time.now.to_f
      end

      on :pong do |data|
        now = Time.now.to_f
        stamp = data.stamp
        delta = now - stamp
        @config.log "Slow ping pong response: #{delta}s" if delta > 5
      end
    end

    def blowup(user, data, args, &respond)
      respond.call "Tick... tick... tick... BOOM!   Goodbye."
      EM.next_tick do
        raise "kablammo!"
      end
    end
  end
end
