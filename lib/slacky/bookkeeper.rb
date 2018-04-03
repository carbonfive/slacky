module Slacky
  class Bookkeeper
    def initialize(client)
      @client = client
    end

    def web_client
      @client.web_client
    end

    def keep_the_books
      @client.on :channel_created do |data|
        web_client.channels_info(channel: data.channel.id).tap do |resp|
          if resp.ok
            channel = Channel.channel resp.channel
            puts "Channel ##{channel.name}: channel_created"
          end
        end
      end

      handle_channel(:channel_deleted)   { |c| c.delete }
      handle_channel(:channel_archive)   { |c| c.archive }
      handle_channel(:channel_unarchive) { |c| c.unarchive }
      handle_channel(:channel_rename)    { |c, data| c.rename data.channel.name }

      @client.on :group_joined do |data|
        next unless data.channel.is_group
        channel = Channel.group data.channel
        puts "Channel ##{channel.name}: group_joined"
      end

      handle_channel(:group_left)        { |g| g.delete }
      handle_channel(:group_archive)     { |g| g.archive }
      handle_channel(:group_unarchive)   { |g| g.unarchive }
      handle_channel(:group_rename)      { |g, data| g.rename data.channel.name }
    end

    def handle_channel(event)
      @client.on event do |data|
        channel_id = data.channel.is_a?(String) ? data.channel : data.channel.id
        Channel.find(channel_id).tap do |channel|
          yield channel, data
          puts "Channel ##{channel.name}: #{event}"
        end
      end
    end

  end
end
