# frozen_string_literal: true

module PastaBot
  class Message
    def initialize(bot, channel_id, id)
      @resource = bot.resource["/channels/#{channel_id}/messages/#{id}"]
    end

    def delete
      @resource.delete
    end

    def edit(new_msg)
      @resource.patch({ content: new_msg }.to_json)
    end
  end
end
