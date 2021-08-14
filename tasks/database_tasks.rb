# frozen_string_literal: true

require 'active_record'
require File.expand_path('../lib/database', __dir__)

class DatabaseTasks
  def self.create
    ActiveRecord::Tasks::DatabaseTasks.create(Database.config_hash)
  end

  def self.prepare
    create
    Database.establish_connection
    ActiveRecord::Tasks::DatabaseTasks.migrate
  end

  def self.drop
    ActiveRecord::Tasks::DatabaseTasks.drop(Database.config_hash)
  end
end
