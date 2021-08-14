# frozen_string_literal: true

require 'active_support'

module Freshdesk
  class TicketsToImport
    attr_reader :config, :client

    delegate :filter, to: :config

    def initialize(config)
      @config = config
      @client = Client.new(config)
    end

    def each(&block)
      client.each_ticket do |ticket|
        next unless should_import?(ticket)

        ticket['conversations'] = client.all_conversations(ticket['id']) if config.include_conversations
        block.call(ticket)
      end
    end

    private

    def should_import?(ticket)
      return true unless filter.respond_to?(:call)

      filter.call(ticket)
    end
  end
end
