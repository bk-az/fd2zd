# frozen_string_literal: true

class Resource < ActiveRecord::Base
  serialize :columns

  default_scope -> { order(fd_id: :asc) }
end

class Ticket < Resource
end

class User < Resource
end

class Contact < User
end

class Agent < User
end

class Product < Resource
end

class Group < Resource
end

class Company < Resource
end
