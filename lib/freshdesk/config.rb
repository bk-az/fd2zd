# frozen_string_literal: true

module Freshdesk
  class Config
    attr_accessor :subdomain, :api_token, :filter, :tickets_updated_since, :include_conversations
  end
end
