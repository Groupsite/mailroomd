require 'logger'
require "aws/s3"

module Mailroom
  extend self
  def logger
    @logger = Logger.new("log/mailroomd.log")
  end

  def root
    File.expand_path(File.dirname(__FILE__))
  end

  def establish_connection!
    config = YAML.load_file(File.join(Mailroom.root, "config/s3.yml")).inject({}) { |h, t| h.merge(t[0].to_sym => t[1])}
    AWS::S3::Base.establish_connection!(config)
  end
end

Mailroom.establish_connection!

Dir[File.expand_path("mailroom/*.rb", Mailroom.root)].each do |r|
  require r
end

