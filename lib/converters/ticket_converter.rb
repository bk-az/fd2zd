# frozen_string_literal: true

class TicketConverter
  attr_reader :fd_ticket

  # === IMPORTANT ===
  #
  # Enter default values for requester_id and assignee_id.
  # This will be used if an agent / customer of freshdesk
  # is not present in zendesk, which is possible if fd user is
  # not valid, e.g, having blank email.
  #
  # For example:
  #
  # DEFAULTS = {
  #   assignee_id: 1234567890,
  #   requester_id: 1234567890,
  #   author_id: 1234567890,
  # }
  #
  DEFAULTS = {
    assignee_id: nil,
    requester_id: nil,
    author_id: nil, # comment author id
  }.freeze

  # Freshdesk to Zendesk status
  STATUS = {
    1 => 'new',
    2 => 'open',
    3 => 'pending',
    4 => 'solved',
    5 => 'closed'
  }.freeze

  # Freshdesk to Zendesk priority
  PRIORITY = {
    1 => 'low',
    2 => 'normal',
    3 => 'high',
    4 => 'urgent'
  }.freeze

  def self.convert(fd_ticket)
    new(fd_ticket).convert
  end

  def self.user_ids_mapping
    @user_ids_mapping ||= User.all.pluck(:fd_id, :zd_id).to_h
  end

  def initialize(fd_ticket)
    @fd_ticket = fd_ticket
  end

  def convert
    {
      external_id: external_id,
      assignee_id: assignee_id,
      requester_id: requester_id,
      subject: subject,
      comments: comments,
      status: 'closed',
      priority: priority,
      created_at: created_at,
      updated_at: updated_at,
      tags: tags,
      # group_id: group_id,
      # custom_fields: custom_fields
    }
  end

  def external_id
    "fd#{fd_ticket['id']}"
  end

  def assignee_id
    user_zd_id(fd_ticket['responder_id']) || DEFAULTS[:assignee_id]
  end

  def requester_id
    user_zd_id(fd_ticket['requester_id']) || DEFAULTS[:requester_id]
  end

  def subject
    "FD##{fd_ticket['id']} - #{fd_ticket['subject']}"
  end

  def comments
    comments_array = []

    comments_array << {
      author_id: requester_id,
      created_at: created_at,
      body: fd_ticket['description_text']
    }

    fd_ticket['conversations'].each do |conversation|
      next if conversation['body_text'].blank?

      comments_array << {
        author_id: user_zd_id(conversation['user_id']),
        created_at: utc_time(conversation['created_at']),
        body: conversation['body_text']
      }
    end

    comments_array
  end

  def status
    STATUS[fd_ticket['status']]
  end

  def priority
    PRIORITY[fd_ticket['priority']]
  end

  def tags
    [
      'freshdesk-import'
    ]
  end

  def created_at
    utc_time(fd_ticket['created_at'])
  end

  def updated_at
    utc_time(fd_ticket['updated_at'])
  end

  # def group_id
  #   # group id mapping logic here
  # end

  # def custom_fields
  #   [
  #     {
  #       id: 360018750920,
  #       value: fd_ticket['custom_fields']['customer_type']
  #     },
  #     {
  #       id: 360018750940,
  #       value: fd_ticket['custom_fields']['bussiness_type']
  #     }
  #   ]
  # end

  private

  def user_zd_id(fd_id)
    return if fd_id.blank?

    self.class.user_ids_mapping[fd_id]
  end

  def utc_time(time)
    Util.utc_format(time)
  end
end
