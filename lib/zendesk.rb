# frozen_string_literal: true

require_relative 'request_handler'
require_relative 'zendesk/client'
require_relative 'zendesk/config'
require_relative 'zendesk/import_resource'
require_relative 'zendesk/tickets_import_service'
require_relative 'zendesk/users_import_service'

module Zendesk
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

    def import_service
      TicketsImportService.new(config)
    end
  end
end
