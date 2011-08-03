require File.expand_path("./init.rb", File.dirname(__FILE__))

trap("TERM") do
  Mailroom::MailSpoolSnapshotter.halt!
end

trap("INT") do
  EventMachine::stop_event_loop
end

Mailroom.logger.info "Starting up..."

begin
  EventMachine::run do
    if Mailroom.mail_spools.any?
      Mailroom.mail_spools.each do |mail_spool|
        Mailroom::MailSpoolSnapshotter.new(mail_spool)
      end
    else
      Mailroom.logger.fatal "No mail spools configured."
      EventMachine::stop_event_loop
    end
  end

  Mailroom.logger.info "Exiting."
rescue Exception => e
  Mailroom.notify(e, :fatal)
  raise
end
