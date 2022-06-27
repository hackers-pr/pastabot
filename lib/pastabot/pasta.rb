# frozen_string_literal: true

module PastaBot::Pasta
  PASTAS_FILE = File.expand_path('~/.pastas.json')
  PASTAS = JSON.parse(File.read(PASTAS_FILE))

  InvalidPastaError = Class.new(StandardError)
  NoSuchPastaError = Class.new(StandardError)

  class << self
    def save
      File.write(PASTAS_FILE, PASTAS.to_json)
    end

    def add(name, pasta)
      raise InvalidPastaError, 'The name of the pasta and the pasta itself cannot be empty' unless name && pasta

      PASTAS[name] = pasta
      save
    end

    def delete(name)
      PASTAS.delete(name)
    end

    def [](name)
      raise NoSuchPastaError, 'There is no pasta by that name' unless PASTAS.key?(name)

      PASTAS[name]
    end

    def list
      PASTAS.keys
    end
  end
end
