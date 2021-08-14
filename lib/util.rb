# frozen_string_literal: true

module Util
  def self.utc_format(value)
    time = value.is_a?(String) ? Time.parse(value) : value
    time.in_time_zone('UTC').strftime('%Y-%m-%dT%H:%M:%SZ')
  rescue
    value
  end
end
