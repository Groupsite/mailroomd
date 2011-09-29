ENV['BUNDLE_GEMFILE'] ||= File.expand_path("./Gemfile", File.dirname(__FILE__))

$: << File.dirname(__FILE__)
require "rubygems"
require "bundler/setup"

require "eventmachine"

require "mailroom"

require "mailroom/config.rb"
require "mailroom/logging.rb"

Dir[File.expand_path("mailroom/*.rb", File.dirname(__FILE__))].each do |r|
  require r
end

Mailroom.extend Mailroom::Logging
Mailroom.extend Mailroom::Config

Mailroom.establish_connection!

if Mailroom.airbrake_enabled?
  require 'hoptoad_notifier'
  HoptoadNotifier.configure do |config|
    config.api_key = Mailroom.airbrake_key
  end
end

`mkdir -p #{Mailroom.temp_directory}`
