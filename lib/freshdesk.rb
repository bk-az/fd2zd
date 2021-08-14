# frozen_string_literal: true

require_relative 'request_handler'
require_relative 'freshdesk/client'
require_relative 'freshdesk/config'
require_relative 'freshdesk/tickets_to_import'

module Freshdesk
  class << self
    def config
      @config ||= Config.new
    end

    def configure(&block)
      block.call(config)
    end

    def client
      Client.new(config)
    end

    def tickets_to_import
      TicketsToImport.new(config)
    end
  end
end
