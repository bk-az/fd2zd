# frozen_string_literal: true

require 'active_support'

module Zendesk
  module ImportResource
    extend ActiveSupport::Concern

    included do
      attr_reader :config, :jobs_count, :threads

      delegate :synchronize, to: :@semaphore
    end

    def initialize(config)
      @config = config
      @semaphore = Mutex.new
      @jobs_count = config.jobs_count || 1
      @threads = []
    end

    def client
      @client ||= Client.new(config)
    end

    def import
      jobs_count.times do
        threads << Thread.new { import_resources }
      end
      threads.map(&:join)
    end

    def resource_klass
      raise 'Not Implemented!'
    end

    def converter_klass
      raise 'Not Implemented!'
    end

    def batch_size
      100
    end

    def bulk_import_options
      {}
    end

    def resource_name
      resource_klass.name.underscore
    end

    def import_resources
      loop do
        resources = []
        synchronize { resources = next_batch }
        break if resources.blank?

        data = build_data(resources)
        begin
          job = client.bulk_import_resources(resource_name.pluralize, data, **bulk_import_options)
        rescue Exception => e
          job = nil
          LOGGER.error "#{e.class.name}: #{e.message}, FD_IDs: #{resources.map(&:fd_id)}"
        end

        job = wait_for_completion!(job) if job

        synchronize { save_progress(resources, job) }
      end
    end

    def next_batch
      resources = []
      with_db_connection do
        resources = resource_klass.where(status: 'new').limit(batch_size).to_a
        resource_klass.where(id: resources.map(&:id)).update_all(status: 'queued') if resources.present?
      end
      thread_id = threads.index Thread.current
      LOGGER.info "THREAD##{thread_id} -- selected #{resource_name} ids: #{resources.map(&:fd_id).join(',')}"
      resources
    end

    def wait_for_completion!(job)
      while %w[queued working].include?(job['job_status']['status'])
        sleep(5)
        job = client.job_status(job['job_status']['id'])
        thread_id = threads.index Thread.current
        LOGGER.info 'THREAD#%d -- %s(%d/%d)' % [thread_id, *job['job_status'].values_at('status', 'progress', 'total')]
      end

      if job['job_status']['status'] != 'completed'
        LOGGER.error 'JobFailed'
        LOGGER.info job.inspect
      end

      job
    end

    def save_progress(resources, job)
      if job.blank?
        with_db_connection { resource_klass.where(id: resources.map(&:id)).update_all(status: 'job-failed') }
        return
      end

      data = job['job_status']['results'].map.with_index do |result, index|
        if result['error']
          { status: 'failed', zd_id: nil, zd_error: "#{result['error']}: #{result['details']}" }
        else
          { status: 'synced', zd_id: result['id'], zd_error: nil }
        end.merge!(id: resources[result['index'] || index].id)
      end
      with_db_connection { resource_klass.upsert_all(data) }
    end

    def build_data(resources)
      data = resources.map { |resource| converter_klass.convert(resource.columns) }
      { resource_name.pluralize => data }
    end

    def with_db_connection(&block)
      ActiveRecord::Base.connection_pool.with_connection { block.call }
    end
  end
end
