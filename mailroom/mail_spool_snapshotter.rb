require 'time'
module Mailroom
  class MailSpoolSnapshotter < EventMachine::Timer
    INTERVAL = 1

    TEMP_DIRECTORY = "/tmp/mailroom"

    attr_reader :mail_spool, :snapshot_filename

    def self.host
      @host ||= `hostname`.split('.').first

    end

    def logger
      Mailroom.logger
    end

    def initialize(mail_spool)
      @mail_spool = mail_spool
      super(INTERVAL) { timer_tick }
    end

    def timer_tick
      logger.info "Acquiring lock on #{mail_spool}"
      EventMachine::defer(lambda { acquire_lock }, lambda { |file| lock_acquired(file) })
    end

    def acquire_lock
      logger.debug "Lock acquire thread started for #{mail_spool}"
      file = File.new(mail_spool)
      file.flock(File::LOCK_EX)
      file
    end

    def lock_acquired(file)
      name = File.basename(mail_spool)
      time = Time.now
      @snapshot_filename = File.join(TEMP_DIRECTORY, "#{time.strftime("%Y%m%d%H%M%S")}-#{self.class.host}-#{name}")
      logger.info("Moving #{mail_spool} to #{snapshot_filename}")
      EventMachine::defer(lambda { move_spool(file) }, lambda { spool_moved })
    end

    def move_spool(file)
      logger.debug "Move spool thread started for #{snapshot_filename}"
      File.rename(mail_spool, snapshot_filename)
      logger.debug "Releasing lock on #{snapshot_filename}"
      file.flock(File::LOCK_UN)
    end

    def spool_moved
      logger.info "Spool moved"
      self.class.new(mail_spool)
    end

  end
end
