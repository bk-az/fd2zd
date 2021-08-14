# frozen_string_literal: true

class UserConverter
  attr_reader :fd_user

  def self.convert(fd_user)
    new(fd_user).convert
  end

  def initialize(fd_user)
    @fd_user = fd_user
  end

  def convert
    {
      email: email,
      name: name,
      external_id: external_id,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def external_id
    "fd#{fd_user['id']}"
  end

  def email
    return fd_user['contact']['email'] if fd_user['contact'].present?

    fd_user['email']
  end

  def name
    return fd_user['contact']['name'] if fd_user['contact'].present?

    fd_user['name']
  end

  def created_at
    Util.utc_format(fd_user['created_at'])
  end

  def updated_at
    Util.utc_format(fd_user['updated_at'])
  end
end
