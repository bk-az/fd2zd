# frozen_string_literal: true

require 'active_support'

module Freshdesk
  # freshdesk api client
  class Client
    include RequestHandler

    delegate :subdomain, :api_token, :tickets_updated_since, to: :@config

    def initialize(config)
      @config = config
      validate!
    end

    def base_url
      "https://#{subdomain}.freshdesk.com/api/v2"
    end

    def authorization
      { Authorization: "Basic #{Base64.strict_encode64("#{api_token}:X")}" }
    end

    def find_resource!(type, id)
      url = "#{base_url}/#{type}/#{id}"
      perform_request(:get, url, authorization)
    end

    def find_resource(type, id)
      find_resource!(type, id)
    rescue RestClient::NotFound
      nil
    end

    def each_page(**params, &block)
      path = params.delete(:path)
      params[:per_page] ||= 100
      params[:page] ||= 1
      response = nil
      loop do
        req_url = "#{base_url}/#{path}?#{params.to_query}"
        response = perform_request(:get, req_url, authorization)

        break if response.length.zero?

        block.call(response)

        break if response.length < params[:per_page] # last page

        # special case, freshdesk does not allow page value greater than 300
        # currenlty only in case of tickets
        if params[:updated_since] && params[:page] == 300
          # some records will repeat, but its handled at database level.
          params[:updated_since] = Util.utc_format(response.last['updated_at'])
          params[:page] = 1
        else
          params[:page] += 1
        end
      end
    end

    def each_resource(resource_name, **args, &block)
      each_page(path: resource_name, **args) do |resources|
        resources.each { |resource| block.call(resource) }
      end
    end

    def all_resources(resource_name, **args)
      result = []
      each_page(path: resource_name, **args) { |resources| result.concat(resources) }
      result
    end

    def find_contact(id)
      find_resource('contacts', id)
    end

    def find_agent!(id)
      find_resource!('agents', id)
    end

    def each_ticket(**args, &block)
      params = { updated_since: tickets_updated_since || '2000-01-01', include: 'description,requester', order_type: 'asc', order_by: 'updated_at' }.merge(args)
      each_resource('tickets', **params, &block)
    end

    def all_conversations(ticket_id)
      all_resources("tickets/#{ticket_id}/conversations")
    end

    private

    def validate!
      raise 'subdomain required!' if !subdomain || subdomain.empty?
      raise 'API token required!' if !api_token || api_token.empty?
    end
  end
end
