# frozen_string_literal: true

require 'json'
require 'rest-client'

# Module to handle API requests
module RequestHandler
  DEFAULT_RETRY_AFTER = 10 # sec
  RETRY_LIMIT = 6

  # Performs request and handles rate limit.
  #
  # Examples:
  # GET: perform_request(:get, url, headers)
  # POST: perform_request(:post, url, payload, headers)
  #
  def perform_request(*args)
    retries = 0
    begin
      JSON.parse(log_and_perform_request(*args))
    rescue RestClient::TooManyRequests => e
      LOGGER.error "#{self.class.name}: Rate limited..!"
      LOGGER.info "RETRY_LIMIT: #{RETRY_LIMIT}, Retries: #{retries}"
      raise(e) if retries >= RETRY_LIMIT

      retry_after = (e.response.headers[:retry_after] || DEFAULT_RETRY_AFTER).to_i
      LOGGER.warn "#{self.class.name}: Retrying in #{retry_after} seconds..."

      retry_after.times do |i|
        time_left = retry_after - i
        LOGGER.info "#{self.class.name}: Retrying in #{time_left} seconds..." if (time_left % 5).zero?
        sleep 1
      end

      LOGGER.info "#{self.class.name}: Retrying..."
      retries += 1
      retry
    rescue RestClient::RequestTimeout, SocketError, Errno::ECONNRESET => e
      LOGGER.error "#{self.class.name}: #{e.class.name}..!"
      retry_after = 30
      LOGGER.warn "#{self.class.name}: Retrying in #{retry_after} seconds..."
      retry_after.times do |i|
        time_left = retry_after - i
        LOGGER.info "#{self.class.name}: Retrying in #{time_left} seconds..." if (time_left % 5).zero?
        sleep 1
      end
      LOGGER.info "#{self.class.name}: Retrying..."
      retry
    rescue RestClient::Exception => e
      LOGGER.error e.message
      LOGGER.info "args: #{args[0..1].inspect}"
      LOGGER.info e.backtrace
      LOGGER.info e.response.body if e.response.present?
      raise(e)
    end
  end

  def log_and_perform_request(*args)
    LOGGER.info "STARTED #{args[0].to_s.upcase} '#{args[1]}'"
    response = RestClient.public_send(*args)
    LOGGER.info "COMPLETED #{args[0].to_s.upcase} '#{args[1]}'"
    response
  end
end
