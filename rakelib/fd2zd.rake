# frozen_string_literal: true

require File.expand_path('../fd2zd', __dir__)

namespace :fd2zd do
  desc 'Load resources in database'
  task :load_resources do
    klass = ENV.fetch('CLASS').constantize

    abort 'run `bundle exec rake fd2zd:load_tickets` to load tickets' if klass == Ticket

    insert_data = []
    Freshdesk.client.each_resource(klass.name.underscore.pluralize) do |resource|
      insert_data << { fd_id: resource['id'], type: klass.name, columns: resource }

      next if insert_data.length < 100 # insert records in batches of 100

      klass.upsert_all(insert_data)
      LOGGER.info "#{klass.count} #{klass.name.pluralize} imported"
      insert_data.clear
    end

    klass.upsert_all(insert_data) if insert_data.length.positive? # insert remaining records
    LOGGER.info "All #{klass.name.pluralize} imported! Total count: #{klass.count}"
  end

  desc 'Load tickets in database'
  task :load_tickets do
    count = 0
    insert_data = []
    last_ticket = Ticket.last

    Freshdesk.config.tickets_updated_since = Util.utc_format(last_ticket.columns['updated_at']) if last_ticket

    # TODO: verify if upsert_all modifies status
    Freshdesk.tickets_to_import.each do |ticket|
      count += 1
      insert_data << { fd_id: ticket['id'], type: 'Ticket', columns: ticket }

      next if insert_data.length < 100 # insert records in batches of 100

      ActiveRecord::Base.connection_pool.with_connection { Ticket.upsert_all(insert_data) }
      LOGGER.info "#{count} Tickets imported"
      insert_data.clear
    end

    Ticket.upsert_all(insert_data) if insert_data.length.positive? # insert remaining records
    LOGGER.info "All Tickets imported! Total count: #{count}"
  end

  desc 'Load required contacts'
  task :load_required_contacts do
    Ticket.in_batches(of: 1000) do |tickets|
      insert_data = tickets.map do |ticket|
        { fd_id: ticket.columns['requester']['id'], type: 'Contact', columns: ticket.columns['requester'] }
      end

      Contact.upsert_all(insert_data)
      LOGGER.info "#{Contact.count} Contacts imported"
    end
    LOGGER.info "All Contacts imported! Total count: #{Contact.count}"
  end

  desc 'Import Users'
  task :import_users do
    service = Zendesk::UsersImportService.new(Zendesk.config)
    service.import
  end

  desc 'Users Import Job Status'
  task :users_import_job_status do
    puts 'Users Import Job Status:'
    loop do
      count_hash = User.all.unscoped.group(:status).count
      print "\r #{count_hash.map { |k, v| "#{k}: #{v}" }.join(' ')}"
      sleep(5)
    end
  end

  desc 'Verify Users Import'
  task :verify_users_import do
    verified_count = 0
    Zendesk.client.each_user do |zd_user|
      user = User.find_by(zd_id: zd_user['id'])
      next if user.nil?

      email = (user.columns['email'].presence || user.columns.dig('contact', 'email').to_s).downcase
      if email == zd_user['email'] && (zd_user['external_id'].blank? || user.fd_id.to_s == zd_user['external_id'].gsub(/[^0-9]/, ''))
        verified_count += 1
      else
        LOGGER.error "Invalid User Import Found, FD_ID: #{user.fd_id}, ZD_ID: #{user.zd_id}, EMAIL: #{email}"
      end

      LOGGER.info "Verified #{verified_count} users" if (verified_count % 1000).zero?
    end
    LOGGER.info "Verified all users, total_count: #{User.count}, verified_count: #{verified_count}"
  end

  desc 'Import tickets in zendesk'
  task :import_tickets do
    service = Zendesk.import_service
    service.import
  end

  desc 'Tickets Import Job Status'
  task :tickets_import_job_status do
    puts 'Tickets Import Job Status:'
    loop do
      count_hash = Ticket.all.unscoped.group(:status).count
      print "\r #{count_hash.map { |k, v| "#{k}: #{v}" }.join(' ')}"
      sleep(5)
    end
  end

  desc 'Verify Tickets Import'
  task :verify_tickets_import do
    count = Hash.new(0)
    Zendesk.client.each_resource('search/export', query: 'status:closed tags:freshdesk-import', filter: { type: 'ticket' }, page: { size: 1000 }) do |ticket|
      LOGGER.info "#{count.length} Tickets processed" if (count.length % 500).zero?

      if ticket['external_id'].blank?
        LOGGER.error "External ID not set!!, ticket_id: #{ticket['id']}"
        next
      end

      fd_id = ticket['external_id'].gsub(/[^0-9]/, '').to_i
      fd_ticket = Ticket.find_by(fd_id: fd_id)

      if fd_ticket.blank?
        LOGGER.error "Ticket not found!!, external_id: #{ticket['external_id']}"
        next
      end

      count[fd_id] += 1

      if fd_ticket.status != 'synced'
        LOGGER.warn "Updating ticket status from '#{fd_ticket.status}' to 'synced', FD_ID: #{fd_id}"
        fd_ticket.update_columns(status: 'synced', zd_id: ticket['id'])
      end

      if fd_ticket.zd_id != ticket['id'].to_i
        LOGGER.warn "Updating ticket zd_id from '#{fd_ticket.zd_id}' to '#{ticket['id']}', FD_ID: #{fd_id}"
        fd_ticket.update_columns(zd_id: ticket['id'])
      end
    end
    LOGGER.info "All tickets verified, total count: #{count.length}"

    if count.values.max > 1
      LOGGER.error 'Multiple tickets found against single FD ID, check "count_hash.yml" which contains count of each zendesk ticket created against freshdesk ticket id.'
    end

    File.open('count_hash.yml', 'w') { |file| file.write(count.to_yaml) }
  end

  desc 'Delete extra users'
  task :delete_extra_users do
    count = 0
    user_ids = []
    Ticket.in_batches(of: 1000) do |tickets|
      tickets.each do |ticket|
        user_ids << ticket.columns['requester_id']
        ticket.columns['conversations'].each { |c| user_ids << c['user_id'] }
      end
      user_ids.compact!
      user_ids.uniq!
      count += tickets.length
      LOGGER.info "#{count} Tickets processed"
    end
    deleted_count = Contact.where.not(fd_id: user_ids).delete_all
    LOGGER.info "Deleted users count: #{deleted_count}"
  end

  desc 'Load missing users'
  task :load_missing_users do
    count = 0
    users_count = User.count
    client = Freshdesk.client
    Ticket.in_batches(of: 1000) do |tickets|
      user_ids = []
      tickets.each do |ticket|
        user_ids << ticket.columns['responder_id']
        user_ids << ticket.columns['requester_id']
        ticket.columns['conversations'].each { |c| user_ids << c['user_id'] }
      end
      user_ids.compact!
      user_ids.uniq!
      user_ids -= User.where(fd_id: user_ids).pluck(:fd_id)
      user_ids.each do |user_id|
        if (contact = client.find_contact(user_id))
          Contact.create!(fd_id: contact['id'], columns: contact)
        else
          LOGGER.info "Loading missing Agent -- ID: #{user_id}"
          agent = client.find_agent!(user_id)
          Agent.create!(fd_id: agent['id'], columns: agent)
        end
      end
      count += tickets.length
      LOGGER.info "#{count} Tickets processed"
    end
    LOGGER.info "All Users imported! Missing users count: #{User.count - users_count}"
  end

  desc 'populate missing emails'
  task :populate_missing_emails do
    User.find_each.with_index do |user, index|
      LOGGER.info "#{index} users processed" if (index % 5000).zero?

      next if user.columns['email'].present? || user.columns['contact'].present?

      user.columns['email'] = "unknown.#{Time.now.to_f}@example.com"
      user.save!
      LOGGER.info "Email populated: #{user.columns['email']}, FD_ID: #{user.fd_id}"
    end
  end

  desc 'Reset resource import status'
  task :reset_import_status do
    klass = ENV.fetch('CLASS').constantize
    klass.all.update_all(status: 'new', zd_id: nil, zd_error: nil)
  end
end
