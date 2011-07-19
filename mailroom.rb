require 'logger'

module Mailroom
  def self.logger
    @logger = Logger.new("log/mailroomd.log")
  end
end

Dir[File.expand_path("mailroom/*.rb", File.dirname(__FILE__))].each do |r|
  require r
end

