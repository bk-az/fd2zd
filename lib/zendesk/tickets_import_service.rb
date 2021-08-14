# frozen_string_literal: true

require 'active_support'

module Zendesk
  class TicketsImportService
    include ImportResource

    def resource_klass
      Ticket
    end

    def converter_klass
      TicketConverter
    end

    def batch_size
      25
    end

    def bulk_import_options
      { archive_immediately: true }
    end
  end
end
