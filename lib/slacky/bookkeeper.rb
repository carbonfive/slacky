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

      handle_channel(:channel_deleted)   { |c| c.delete }
      handle_channel(:channel_archive)   { |c| c.archive }
      handle_channel(:channel_unarchive) { |c| c.unarchive }
      handle_channel(:channel_rename)    { |c, data| c.name = data.channel.name }
    end

    def handle_channel(event)
      @client.on event do |data|
        channel_id = data.channel.is_a?(String) ? data.channel : data.channel.id
        Channel.find(channel_id).tap do |channel|
          yield channel, data
          verb = event.to_s.split("_").last
          verb = "#{verb}d" if verb =~ /e$/
          verb = "#{verb}ed" unless verb =~ /ed$/
          puts "Channel ##{channel.name} was #{verb}"
        end
      end
    end
  end
end
