require 'slack-ruby-client'
require 'set'
require 'tzinfo'

module Slacky
  class Bot
    attr_reader :client, :config, :slack_id

    def initialize(config)
      @config = config
      @restarts = []
      @channels = Set.new
      @message_handlers = []

      unless @config.slack_api_token
        @config.log "No Slack API token found in #{@config.down_name}.yml!"
        return
      end

      Slack.configure do |slack_cfg|
        slack_cfg.token = @config.slack_api_token
      end

      @client = Slack::RealTime::Client.new

      auth = @client.web_client.auth_test
      if auth.ok
        @slack_id = auth.user_id
        @config.log "Slackbot is active!"
        @config.log "Accepting channels: #{@config.slack_accept_channels}" if @config.slack_accept_channels.length > 0
        @config.log "Ignoring channels: #{@config.slack_reject_channels}" if @config.slack_reject_channels.length > 0
      else
        puts "Slackbot cannot authorize with Slack.  Boo :-("
        @config.log "Slackbot is doomed :-("
        return
      end

      resp = @client.web_client.users_list presence: 1
      throw resp unless resp.ok
      resp.members.each do |member|
        next unless member.profile.email # no bots
        next if member.deleted # no ghosts
        next if member.is_ultra_restricted # no single channel guests
        user = User.find(member.id) || User.new(slack_id: member.id)
        user.username = member.name
        user.first_name = member.profile.first_name
        user.last_name = member.profile.last_name
        user.email = member.profile.email
        user.timezone = member.tz
        user.presence = member.presence
        user.data = {} unless user.data
        user.save
      end
    end

    def on(message, &block)
      @message_handlers << { message: message, handler: block }
    end

    def on_help(&block)
      @help_handler = block
    end

    def run
      @client.on :message do |data|
        next if data.user == @slack_id
        next unless data.text
        tokens = data.text.split ' '
        channel = data.channel
        next unless tokens.length > 0
        next if @config.slack_reject_channels.index channel
        user = User.find data.user
        next unless user
        if channel == user.slack_im_id
          tokens.shift if tokens.first.downcase == @config.down_name
        else
          first = tokens.shift
          next unless ( channel =~ /^D/ || first.downcase == @config.down_name )
          next if @config.slack_accept_channels.length > 0 and ! @config.slack_accept_channels.include?(channel)
        end
        @client.typing channel: channel
        @channels << channel
        respond = Proc.new { |msg| @client.message channel: channel, reply_to: data.id, text: msg }
        message = tokens.join ' '
        command = tokens.first
        args = tokens[1..-1]
        blowup if command == 'blowup'
        handled = 0
        @message_handlers.each do |mh|
          if mh[:message] === message
            puts "Executing command: #{mh[:message]}"
            handled += 1 if mh[:handler].call(user, data, args, &respond)
          end
        end
        @help_handler.call(user, data, args, &respond) if handled == 0
      end

      @client.on :presence_change do |data|
        user = User.find data.user
        next unless user
        user.presence = data['presence']
        user.save
      end

      puts "Slackbot is active!"
      @client.start!
    rescue => e
      @config.log "An error ocurring inside the Slackbot", e
      @restarts << Time.new
      @restarts.shift while (@restarts.length > 3)
      if @restarts.length == 3 and ( Time.new - @restarts.first < 30 )
        @config.log "Too many errors.  Not restarting anymore."
        @client.on :hello do
          @channels.each do |channel|
            @client.message channel: channel, text: "Oh no... I have died!  Please make me live again @mike"
          end
          @client.stop!
        end
        @client.start!
      else
        run
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
