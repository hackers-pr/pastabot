# frozen_string_literal: true

require 'websocket-client-simple'
require 'rest-client'
require 'logger'
require 'json'

module WebSocket
  module Client
    module Simple
      class Client
        attr_reader :thread
      end
    end
  end
end

class PastaBot
  module Opcode
    DISPATCH = 0
    HEARTBEAT = 1
    IDENTIFY = 2
    RESUME = 6
    RECONNECT = 7
    INVALID_SESSION = 9
    HELLO = 10
  end

  def initialize
    @logger = Logger.new($stdout)
    @resource = RestClient::Resource.new(
      'https://discord.com/api/v9',
      headers: {
        authorization: ENV['TOKEN'],
        content_type: 'application/json'
      }
    )
    @pastas = JSON.parse(File.read('pastas.json'))
    @resume = false
  end

  def run
    @ws = WebSocket::Client::Simple.connect('wss://gateway.discord.gg/?v=9&encoding=json')

    @ws.on(:message, &method(:handle_message))
    @ws.on(:open) { @logger.info('Connected') }
    @ws.on(:close, &method(:handle_close))

    begin
      @ws.thread.join
    rescue Interrupt
      @resume = false
      @ws.close
    ensure
      File.write('pastas.json', @pastas.to_json)
    end
  end

  private

  def handle_message(msg)
    @payload = JSON.parse(msg.data)
    @data = @payload['d']

    case @payload['op']
    when Opcode::DISPATCH then handle_dispatch
    when Opcode::RECONNECT then handle_reconnect
    when Opcode::INVALID_SESSION then handle_invalid_session
    when Opcode::HELLO then handle_hello
    end
  end

  def handle_close(_e)
    @logger.warn('Disconnected')
    @heartbeat&.kill

    if @resume
      @logger.warn('Able to resume, reconnecting...')
      run
    else
      @logger.fatal('Unable to resume')
    end
  end

  def handle_dispatch
    @seq = @payload['s']

    case @payload['t']
    when 'READY' then handle_ready
    when 'RESUMED' then @logger.info('Succesfully resumed')
    when 'MESSAGE_CREATE' then handle_message_create
    end
  end

  def handle_hello
    @logger.debug('Received hello payload')
    setup_heartbeat
    @resume ? send_resume : send_identify
  end

  def handle_reconnect
    @logger.warn('Received reconnect payload, reconnecting...')
    @resume = true
    @ws.close
  end

  def handle_invalid_session
    @logger.warn('Received invalid session payload')
    @resume = @data
    @ws.close
  end

  def handle_ready
    @logger.info('Successfully logged in')
    @user_id = @data['user']['id']
    @session_id = @data['session_id']
    @resume = true
  end

  def handle_message_create
    return if @data['author']['id'] != @user_id

    prefix, cmd, name, pasta = @data['content'].split(' ', 4)
    handle_commands(cmd, name, pasta) if prefix == 'pastabot'
  end

  def handle_commands(cmd, name, pasta)
    case cmd
    when 'ping' then reply('pong')
    when 'add' then add_pasta(name, pasta)
    when 'remove' then remove_pasta(name, pasta)
    when 'send' then send_pasta(name)
    end
  end

  def add_pasta(name, pasta)
    unless name && pasta
      reply('The name of the pasta and the pasta itself cannot be empty')
      return
    end

    @pastas[name] = pasta
  end

  def remove_pasta(name, _pasta)
    return if pasta_does_not_exist?(name)

    @pastas.delete(name)
  end

  def send_pasta(name)
    return if pasta_does_not_exist?(name)

    reply(@pastas[name])
  end

  def pasta_does_not_exist?(name)
    return false if @pastas.key?(name)

    reply('There is no such pasta')
    true
  end

  def send(msg)
    @ws.send(msg.to_json)
  end

  def send_heartbeat
    send('op' => Opcode::HEARTBEAT, 'd' => @seq)
    @logger.debug('Sent heartbeat payload')
  end

  def setup_heartbeat
    @interval = @data['heartbeat_interval'] / 1000.0
    @heartbeat = Thread.new do
      loop do
        send_heartbeat
        sleep(@interval)
      end
    end
    @logger.debug('Created heartbeat thread')
  end

  def send_identify
    send(
      op: Opcode::IDENTIFY,
      d: {
        token: ENV['TOKEN'],
        properties: { '$os' => 'linux' },
        intents: 1 << 9 | 1 << 15
      }
    )
    @logger.debug('Sent identify payload')
  end

  def send_resume
    send(
      op: Opcode::RESUME,
      d: {
        token: ENV['TOKEN'],
        session_id: @session_id,
        seq: @seq
      }
    )
    @resume = false
    @logger.debug('Sent resume payload')
  end

  def reply(content)
    @resource["/channels/#{@data['channel_id']}/messages"].post({ content: content }.to_json)
  end
end

bot = PastaBot.new
bot.run
