require 'logger'
require "aws/s3"
require 'hoptoad_notifier'

module Mailroom
  extend self

  def logger
    unless defined? @logger
      @logger = Logger.new(File.join(root, "log", "mailroomd.log"))
      @logger.level = log_level
      @logger.formatter = proc do |severity, datetime, progname, msg|
        [datetime.strftime("%b %d %H:%M:%S"),
         Mailroom.host,
         "#{$0}[#{$$}]:",
         "<#{severity}>",
         msg].join(" ") + "\n"
      end
    end
    @logger
  end

  def log_level
    if ENV["LOG_LEVEL"]
      Logger.const_get(ENV["LOG_LEVEL"])
    else
      Logger::INFO
    end
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

  def notify(e, severity = :error)
    logger.send severity, "#{e}\n#{e.backtrace.join("\n")}"
    HoptoadNotifier.notify(e) if airbrake_enabled?
  end

  def airbrake_enabled?
    config['airbrake_key']
  end

  def host
    @host ||= `hostname`.split('.').first.strip
  end

  def mail_spools
    config["mail_spools"] || []
  end
end

Mailroom.establish_connection!

if Mailroom.airbrake_enabled?
  HoptoadNotifier.configure do |config|
    config.api_key = Mailroom.config['airbrake_key']
  end
end

Dir[File.expand_path("mailroom/*.rb", Mailroom.root)].each do |r|
  require r
end

