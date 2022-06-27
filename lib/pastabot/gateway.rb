# frozen_string_literal: true

require 'websocket-client-simple'

module WebSocket
  module Client
    module Simple
      class Client
        attr_reader :thread
      end
    end
  end
end

module PastaBot
  class Gateway
    module Opcode
      DISPATCH = 0
      HEARTBEAT = 1
      IDENTIFY = 2
      RESUME = 6
      RECONNECT = 7
      INVALID_SESSION = 9
      HELLO = 10
    end

    def initialize(bot)
      @bot = bot
    end

    def run
      loop { connect }
    rescue Interrupt
    ensure
      @ws.close
    end

    private

    def connect
      @ws = WebSocket::Client::Simple.connect('wss://gateway.discord.gg/?v=9&encoding=json')

      @ws.on(:message, &method(:handle_message))
      @ws.on(:open) { LOGGER.info('Connected') }
      @ws.on(:error) { |e| raise e }
      @ws.on(:close, &method(:handle_close))

      @ws.thread.join
    end

    def handle_message(msg)
      payload = JSON.parse(msg.data)

      case payload['op']
      when Opcode::DISPATCH then handle_dispatch(payload)
      when Opcode::RECONNECT, Opcode::INVALID_SESSION then reconnect
      when Opcode::HELLO then handle_hello(payload)
      end
    end

    def handle_close(_e)
      LOGGER.warn('Disconnected')
      @heartbeat&.kill
    end

    def handle_dispatch(payload)
      @bot.dispatch(payload['t'], payload['d'])
    end

    def handle_hello(payload)
      LOGGER.debug('Received hello payload')
      setup_heartbeat(payload)
      send_identify
    end

    def reconnect
      LOGGER.warn('Reconnecting...')
      @ws.close
    end

    def send(msg)
      @ws.send(msg.to_json)
    end

    def send_heartbeat
      send('op' => Opcode::HEARTBEAT, 'd' => @seq)
      LOGGER.debug('Sent heartbeat payload')
    end

    def setup_heartbeat(payload)
      @heartbeat = Thread.new do
        interval = payload['d']['heartbeat_interval'] / 1000.0

        loop do
          send_heartbeat
          sleep(interval)
        end
      end
      LOGGER.debug('Created heartbeat thread')
    end

    def send_identify
      send(
        op: Opcode::IDENTIFY,
        d: {
          token: @bot.token,
          properties: { '$os' => 'linux' },
          intents: 1 << 9 | 1 << 12 | 1 << 15
        }
      )
      LOGGER.debug('Sent identify payload')
    end
  end
end
