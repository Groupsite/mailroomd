require "time"

module Mailroom
  class MailSpoolSnapshotter < EventMachine::Timer
    INTERVAL = 1

    TEMP_DIRECTORY = "/tmp/mailroom"
    S3_INBOX = "/mailroom/mbox/incoming"

    cattr_accessor :active_count
    self.active_count = 0
    attr_reader :mail_spool, :snapshot_filename

    def self.host
      @host ||= `hostname`.split('.').first
    end

    def self.halted?
      !!@halted
    end

    def self.halt!
      Mailroom.logger.info("Winding down...") unless halted?
      @halted = true
    end

    def logger
      Mailroom.logger
    end

    def initialize(mail_spool)
      @mail_spool = mail_spool
      self.class.active_count += 1
      super(INTERVAL) { timer_tick }
    end

    def reset!
      self.class.new(mail_spool) unless self.class.halted?
    end

    def deactivate!
      self.class.active_count -= 1
      if self.class.active_count < 1
        EventMachine::stop_event_loop
      end
    end

    def timer_tick
      logger.info "Acquiring lock on #{mail_spool}"
      EventMachine::defer(lambda { acquire_lock }, lambda { |file| lock_acquired(file) })
    end

    def acquire_lock
      log_errors do
        logger.debug "Lock acquire thread started for #{mail_spool}"
        if File.exists?(mail_spool)
          file = File.new(mail_spool)
          file.flock(File::LOCK_EX)
          file
        end
      end
    end

    def lock_acquired(file)
      if file
        name = File.basename(mail_spool)
        time = Time.now
        @snapshot_filename = File.join(TEMP_DIRECTORY, "#{time.strftime("%Y%m%d%H%M%S")}-#{self.class.host}-#{name}")
        logger.info("Moving #{mail_spool} to #{snapshot_filename}")
        EventMachine::defer(lambda { move_spool(file) }, lambda { spool_moved })
      else
        # No file to lock!
        logger.info("File does not exist: #{mail_spool}")
        reset!
        deactivate!
      end
    end

    def move_spool(file)
      log_errors do
        logger.debug "Move spool thread started for #{snapshot_filename}"
        File.rename(mail_spool, snapshot_filename)
        logger.debug "Releasing lock on #{snapshot_filename}"
        file.flock(File::LOCK_UN)
      end
    end

    def spool_moved
      reset!
      logger.info "Snapshot taken: #{snapshot_filename}"
      EventMachine::defer(lambda { transfer_snapshot }, lambda { snapshot_transfered })
    end

    def transfer_snapshot
      log_errors do
        logger.debug "Transfer thread start for #{snapshot_filename}"
        logger.info "Transfering #{snapshot_filename} to S3"
        io = open(snapshot_filename)
        logger.debug "Snapshot file #{snapshot_filename} opened"
        AWS::S3::S3Object.store(s3_key, io)
      end
    end

    def snapshot_transfered
      logger.info "Snapshot #{snapshot_filename} transfered to S3"
      post_snapshot
    end

    def post_snapshot
      # TODO:
      #  - Use SSH
      #  - Put host, request path, basic auth in config file
      #  - Put params in right place ?content?
      logger.info "Posting #{s3_key} to application"
      http = EventMachine::Protocols::HttpClient.request(:host => Mailroom.api_config["host"],
                                                         :request => Mailroom.api_config["path"],
                                                         :verb => "POST",
                                                         :basic_auth => { :username => Mailroom.api_config["username"],
                                                           :password => Mailroom.api_config["password"] },
                                                         :query_string => "bucket=#{AWS::S3::S3Object.current_bucket}&key=#{s3_key}")
      http.callback { snapshot_posted }
    end

    def snapshot_posted
      logger.info "Snapshot complete: #{s3_key}"
      deactivate!
    end

    def log_errors
      begin
        yield
      rescue Exception => e
        logger.error "#{e}\n#{e.backtrace.join("\n")}"
        raise
      end
    end

    def s3_key
      File.join(S3_INBOX, File.basename(snapshot_filename))
    end
  end
end
