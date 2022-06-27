# frozen_string_literal: true

require 'rest-client'
require 'logger'
require 'json'

require './pastabot/gateway'
require './pastabot/message'
require './pastabot/pasta'

module PastaBot
  class Bot
    attr_reader :token, :resource

    InvalidTokenError = Class.new(StandardError)

    def initialize(token, prefix)
      @token = token
      @prefix = prefix

      @resource = RestClient::Resource.new(
        'https://discord.com/api/v9',
        headers: {
          authorization: @token,
          content_type: 'application/json'
        }
      )

      raise InvalidTokenError, 'Invalid token' if token_invalid?

      @gateway = Gateway.new(self)
    end

    def run
      @gateway.run
    end

    def dispatch(event, data)
      case event
      when 'READY' then handle_ready(data)
      when 'MESSAGE_CREATE' then handle_message_create(data)
      end
    end

    private

    def handle_ready(data)
      LOGGER.info('Successfully logged in')

      user = data['user']
      @user_id = user['id']
      @max_msg_size = user['premium_type'] == 2 ? 4000 : 2000
    end

    def handle_message_create(data)
      return if data['author']['id'] != @user_id

      msg = data['content']

      return unless msg.start_with?(@prefix)

      cmd, name, pasta = msg.delete_prefix(@prefix).split(' ', 3)
      handle_commands(Message.new(self, data['channel_id'], data['id']), cmd, name, pasta)
    end

    def handle_commands(msg, cmd, name, pasta)
      case cmd
      when 'a' then add_pasta(msg, name, pasta)
      when 'd' then delete_pasta(msg, name)
      when 's' then send_pasta(msg, name)
      when 'l' then pasta_list(msg)
      end
    end

    def add_pasta(msg, name, pasta)
      Pasta.add(name, pasta)
      msg.delete
    rescue Pasta::InvalidPastaError => e
      msg.edit(e.message) 
    end
  
    def delete_pasta(msg, name)
      Pasta.delete(name)
      msg.delete
    end
  
    def send_pasta(msg, name)
      msg.edit(Pasta[name])
    rescue Pasta::NoSuchPastaError => e
      msg.edit(e.message)     
    end
  
    def pasta_list(msg)
      new_msg = Pasta.list.join(',')

      if new_msg.size > @max_msg_size
        msg.edit('The message is too long, it will be displayed in the terminal')
        puts new_msg
      end

      msg.edit(new_msg)
    end

    def send(msg)
      @ws.send(msg.to_json)
    end

    def token_invalid?
      @resource['/users/@me'].get
    rescue RestClient::Unauthorized
      true
    else
      false
    end
  end
end
