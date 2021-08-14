# frozen_string_literal: true

require 'active_support'

module Zendesk
  # zendesk api client
  class Client
    include RequestHandler

    delegate :subdomain, :api_token, :admin_email, to: :@config

    def initialize(config)
      @config = config
      validate!
    end

    def base_url
      "https://#{subdomain}.zendesk.com/api/v2"
    end

    def authorization
      { Authorization: "Basic #{Base64.strict_encode64("#{admin_email}/token:#{api_token}")}" }
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
      req_url = "#{base_url}/#{path}?#{params.to_query}"
      loop do
        break if req_url.blank?

        response = perform_request(:get, req_url, authorization)
        resources = response.key?('results') ? response['results'] : response[path]
        break if resources.length.zero?

        block.call(resources)

        req_url = next_page_url(response, path, params)
      end
      LOGGER.info "All pages of #{path} has been loaded!"
    end

    def each_resource(resource_name, **args, &block)
      each_page(path: resource_name, **args) do |resources|
        resources.each { |resource| block.call(resource) }
      end
    end

    def bulk_import_resources(resource_name, data, **params)
      url = "#{base_url}#{bulk_import_path(resource_name)}"
      url = "#{url}?#{params.to_query}" if params.present?
      perform_request(:post, url, JSON.generate(data), { content_type: 'application/json' }.merge!(authorization))
    end

    def search(limit: 100, **params)
      results = []
      url = "#{base_url}/search.json?#{params.to_query}"
      loop do
        response = perform_request(:get, url, authorization)
        break if response['results'].blank?

        results.concat(response['results'])
        url = response['next_page']
        break if url.blank? || results.length >= limit
      end
      results
    end

    def bulk_soft_delete(ids)
      url = "#{base_url}/tickets/destroy_many?ids=#{ids.join(',')}"
      job = perform_request(:delete, url, authorization)
      job = wait_for_completion!(job)
      job['job_status']['results']
    end

    def bulk_permanent_delete(ids)
      url = "#{base_url}/deleted_tickets/destroy_many?ids=#{ids.join(',')}"
      job = perform_request(:delete, url, authorization)
      job = wait_for_completion!(job)
      job['job_status']['results']
    end

    def wait_for_completion!(job)
      while %w[queued working].include?(job['job_status']['status'])
        sleep(5)
        job = job_status(job['job_status']['id'])
        id, status, progress, total = job['job_status'].values_at('id', 'status', 'progress', 'total')
        LOGGER.info "JOB##{id} -- #{status}(#{progress}/#{total})"
      end

      raise 'JobFailed' if job['job_status']['status'] != 'completed'

      job
    end

    def each_user(**args, &block)
      each_resource('users', **args, &block)
    end

    def job_status(id)
      find_resource('job_statuses', id)
    end

    def bulk_import_path(resource_name)
      case resource_name
      when 'tickets'
        '/imports/tickets/create_many'
      else
        "/#{resource_name}/create_many"
      end
    end

    private

    def next_page_url(response, path, params)
      return response['next_page'] if response.key?('next_page')

      return response['links']['next'] if response.key?('links') && response['links']['next'].present?

      return '' if response['meta'].blank? || !response['meta']['has_more'] || response['meta']['after_cursor'].blank?

      params[:page] ||= {}
      page[:page][:after] = response['meta']['after_cursor']
      "#{base_url}/#{path}?#{params.to_query}"
    end

    def validate!
      raise 'subdomain required!' if subdomain.blank?
      raise 'API token required!' if api_token.blank?
      raise 'Admin email required!' if admin_email.blank?
    end
  end
end
