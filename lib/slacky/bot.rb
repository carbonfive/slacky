require 'slack-ruby-client'
require 'set'
require 'tzinfo'

module Slacky
  class Bot

    attr_reader :client

    def initialize(config)
      @config = config
      @restarts = []
      @channels = Set.new
      @message_handlers = []

      Slack.configure do |slack_cfg|
        slack_cfg.token = @config.slack_api_token
      end

      @client = Slack::RealTime::Client.new
    end

    def on(message, &block)
      @message_handlers << { message: message, handler: block }
    end

    def run
      unless @config.slack_api_token
        @config.log "No Slack API token found in #{@config.down_name}.yml!"
        return
      end

      auth = @client.web_client.auth_test
      if auth['ok']
        @config.log "Slackbot is active!"
        @config.log "Accepting channels: #{@config.slack_accept_channels}" if @config.slack_accept_channels.length > 0
        @config.log "Ignoring channels: #{@config.slack_reject_channels}" if @config.slack_reject_channels.length > 0
      else
        puts "Slackbot cannot authorize with Slack.  Boo :-("
        @config.log "Slackbot is doomed :-("
        return
      end

      puts "Slackbot is active!"

      @client.on :message do |data|
        next if data.user == @config.slackbot_id # this is the bot!
        next unless data.text
        tokens = data.text.split ' '
        channel = data.channel
        next unless tokens.length > 0
        next unless tokens[0].downcase == @config.down_name
        next if @config.slack_accept_channels.length > 0 and ! @config.slack_accept_channels.index(channel)
        next if @config.slack_reject_channels.index channel
        @client.typing channel: channel
        @channels << channel
        respond = Proc.new { |msg| @client.message channel: channel, reply_to: data.id, text: msg }
        message = tokens[1..-1].join ' '
        command = tokens[1]
        args = tokens[2..-1]
        command = 'help' unless command
        blowup if command == 'blowup'
        @message_handlers.each do |mh|
          if message === mh[:message]
            puts "Executing command: #{command}"
            mh[:block].call command, args, data, &respond
          end
        end
      end

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

    def blowup(data, args, &respond)
      respond.call "Tick... tick... tick... BOOM!   Goodbye."
      EM.next_tick do
        raise "kablammo!"
      end
    end
  end
end
