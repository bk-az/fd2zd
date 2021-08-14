# frozen_string_literal: true

class Database
  class Config
    attr_accessor :adapter, :encoding, :username, :password, :database

    def to_h
      Hash[instance_variables.map { |name| [name[1..-1], instance_variable_get(name)] }]
    end
  end

  class << self
    def config
      @config ||= Config.new
    end

    def configure(&block)
      block.call(config)
    end

    def config_hash
      config.to_h
    end

    def establish_connection
      ActiveRecord::Base.establish_connection(config_hash)
    end
  end
end
