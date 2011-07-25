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

  def config
    @config ||= YAML.load_file(File.join(Mailroom.root, "config.yml"))
  end

  def api_config
    config["api"] || {}
  end

  def s3config
    config["s3"].inject({}) { |h, t| h.merge(t[0].to_sym => t[1])}.merge(:pool_size => EventMachine.threadpool_size)
  end

  def establish_connection!
    AWS::S3::Base.establish_connection!(s3config)
  end
end

Mailroom.establish_connection!

Dir[File.expand_path("mailroom/*.rb", Mailroom.root)].each do |r|
  require r
end

