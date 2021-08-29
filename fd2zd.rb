# frozen_string_literal: true

require 'active_record'
require 'base64'
require 'yaml'

require_relative 'lib/customize_logger'
require_relative 'lib/util'
require_relative 'lib/converters/user_converter'
require_relative 'lib/converters/ticket_converter'
require_relative 'lib/freshdesk'
require_relative 'lib/zendesk'
require_relative 'lib/database'
require_relative 'tasks/database_tasks'
require_relative 'app/models/resource'

LOGGER = Logger.new './log/import.log'

Thread.abort_on_exception = true

Freshdesk.configure do |config|
  config.subdomain = 'FRESHDESK_SUBDOMAIN'
  config.api_token = 'FRESHDESK_API_TOKEN'
  config.include_conversations = true
  # only import tickets with status IN (4, 5)
  # to import all tickets you can simply return true, for example:
  #
  # config.filter = ->(ticket) { true }
  config.filter = ->(ticket) { ticket['status'] == 4 || ticket['status'] == 5 }
  config.tickets_updated_since = '2010-01-01'
end

# NOTE: make sure to disable help center, user should not receive emails
Zendesk.configure do |config|
  config.subdomain = 'ZENDESK_SUBDOMAIN'
  config.api_token = 'ZENDESK_API_TOKEN'
  config.admin_email = 'ZENDESK_ADMIN_EMAIL'
  config.jobs_count = 4
end

Database.configure do |config|
  config.adapter  = 'mysql2'
  config.encoding = 'utf8mb4'
  config.username = 'root'
  config.password = 'DB_PASSWORD'
  config.database = 'fd2zd'
end

Database.establish_connection
