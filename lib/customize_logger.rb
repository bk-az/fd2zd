# frozen_string_literal: true

require 'logger'

class Logger
  class LogDevice
    alias old_write write

    # output to both stdout and log file
    def write(message)
      old_write(message)
      puts message
    end
  end
end
