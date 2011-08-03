require 'logger'
module Mailroom
  module Logging
    extend Config

    def self.logger
      unless @logger
        @logger = Logger.new(File.join(Mailroom.root, "log", "mailroomd.log"))
        @logger.level = Logger.const_get(log_level)
        @logger.formatter = proc do |severity, datetime, progname, msg|
          lines = msg.split("\n")
          lines_format = lines.size > 1 ? "[%0#{lines.size.to_s.size}d/#{lines.size}]" : ""
          format = [datetime.strftime("%b %d %H:%M:%S"),
                    Mailroom.host,
                    "#{File.basename($0)}[#{$$}]:",
                    "<#{severity}#{lines_format}>"].join(" ")
          i = 0
          lines.map { |line| (format % i+=1) + " #{line}"}.join("\n") + "\n"
        end
      end
      @logger
    end

    def logger
      Mailroom::Logging.logger
    end
  end
end
