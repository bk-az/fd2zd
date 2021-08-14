# frozen_string_literal: true

require File.expand_path('../tasks/database_tasks', __dir__)

namespace :db do
  desc 'Prepare Database'
  task :prepare do
    Rake::Task['db:drop'].invoke if ENV['RESET_DB'] == 'true'
    DatabaseTasks.prepare
  end

  desc 'Drop Database'
  task :drop do
    DatabaseTasks.drop
  end
end
