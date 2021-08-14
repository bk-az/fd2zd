# frozen_string_literal: true

module Zendesk
  class UsersImportService
    include ImportResource

    def resource_klass
      User
    end

    def converter_klass
      UserConverter
    end

    def batch_size
      100
    end

    def bulk_import_options
      {}
    end

    def import
      scan_pre_created_users
      super
    end

    private

    def scan_pre_created_users
      users_hash = build_users_hash
      data = []
      client.each_user do |user|
        next unless users_hash.key?(user['email'])

        users_hash[user['email']].each do |user_id|
          data << { id: user_id, status: 'synced', zd_id: user['id'] }
        end

        next if data.length < 100

        User.upsert_all(data)
        data = []
      end
      User.upsert_all(data) if data.present?
      LOGGER.info 'All Pre-Created Users imported'
    end

    def build_users_hash
      LOGGER.info 'Building Users Hash...'
      hash = Hash.new { |h, k| h[k] = [] }
      User.where.not(status: 'synced').find_each do |user|
        email = user.columns['email'].presence || user.columns['contact']['email']
        hash[email.downcase] << user.id
        LOGGER.info "#{hash.length} users processed" if (hash.length % 5000).zero?
      end
      LOGGER.info 'Users Hash Build Success'
      hash
    end
  end
end
