# frozen_string_literal: true

require './pastabot/bot'

module PastaBot
  LOGGER = Logger.new($stdout)
  LOGGER.level = Logger::DEBUG
end

bot = PastaBot::Bot.new(ENV['TOKEN'], 'p!')
bot.run
