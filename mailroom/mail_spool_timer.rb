module Mailroom
  class MailSpoolTimer < EventMachine::PeriodicTimer
    INTERVAL = 1

    attr_reader :mail_spool

    def initialize(mail_spool)
      @mail_spool = mail_spool
      super(INTERVAL) { acquire_lock }
    end

    def acquire_lock
      puts "Acquiring lock on #{mail_spool}"
    end
  end
end
