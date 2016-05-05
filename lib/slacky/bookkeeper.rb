module Slacky
  class Bookkeeper
    def initialize(client)
      @client = client
    end

    def web_client
      @client.web_client
    end

    def keep_the_books
      @client.on :presence_change do |data|
        next unless ( user = User.find data.user )
        user.presence = data['presence']
        user.save
      end

      @client.on :channel_created do |data|
        web_client.channels_info(channel: data.channel.id).tap do |resp|
          if resp.ok
            channel = Channel.channel resp.channel
            puts "Channel ##{channel.name} was created"
          end
        end
      end

      @client.on :channel_deleted do |data|
        Channel.find(data.channel).tap do |channel|
          channel.delete
          puts "Channel ##{channel.name} was deleted"
        end
      end

      @client.on :channel_archive do |data|
        Channel.find(data.channel).tap do |channel|
          channel.archive
          puts "Channel ##{channel.name} was archived"
        end
      end

      @client.on :channel_unarchive do |data|
        Channel.find(data.channel).tap do |channel|
          channel.unarchive
          puts "Channel ##{channel.name} was un-archived"
        end
      end
    end
  end
end
