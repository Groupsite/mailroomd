require "aws/s3"

module Mailroom
  extend self

  def root
    File.expand_path(File.dirname(__FILE__))
  end

  def establish_connection!
    AWS::S3::Base.establish_connection!(s3config)
  end

  def notify(e, severity = :error)
    logger.send severity, "#{e}\n#{e.backtrace.join("\n")}"
    HoptoadNotifier.notify(e) if airbrake_enabled?
  end

  def airbrake_enabled?
    !!airbrake_key
  end

  def host
    @host ||= `hostname`.split('.').first.strip
  end
end

