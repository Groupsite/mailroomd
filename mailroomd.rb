$: << File.dirname(__FILE__)

require "eventmachine"

require "mailroom"

timers = {}

trap("TERM") do
  Mailroom::MailSpoolSnapshotter.halt!
end

trap("INT") do
  EventMachine::stop_event_loop
end

Mailroom.logger.info "Starting up"

begin
  EventMachine::run do
    ARGV.each do |mailspool|
      Mailroom::MailSpoolSnapshotter.new(mailspool)
    end
  end

  Mailroom.logger.info "Exiting."
rescue Exception => e
  Mailroom.notify(e, :fatal)
  raise
end
