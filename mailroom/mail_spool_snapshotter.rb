require "time"
require "em-http-request"

module Mailroom
  class MailSpoolSnapshotter < EventMachine::Timer
    INTERVAL = 1

    def self.temp_directory
      Mailroom.config["temp_directory"] || "/tmp/mailroom"
    end

    S3_INBOX = "/mailroom/mbox/incoming"

    cattr_accessor :active_count
    self.active_count = 0
    attr_reader :mail_spool, :snapshot_filename

    def self.host
      @host ||= `hostname`.split('.').first.strip
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
      unless self.class.halted? || @has_reset
        self.class.new(mail_spool)
        @has_reset = true
      end
    end

    def deactivate!
      self.class.active_count -= 1
      if self.class.active_count < 1
        EventMachine::stop_event_loop
      end
    end

    def timer_tick
      logger.debug "Acquiring lock on #{mail_spool}"
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
        @snapshot_filename = File.join(self.class.temp_directory, "#{time.strftime("%Y%m%d%H%M%S")}-#{self.class.host}-#{name}")
        logger.debug("Moving #{mail_spool} to #{snapshot_filename}")
        EventMachine::defer(lambda { move_spool(file) }, lambda { |r| spool_moved })
      else
        # No file to lock!
        logger.warn("File does not exist: #{mail_spool}")
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
      EventMachine::defer(lambda { transfer_snapshot }, lambda { |r| snapshot_transfered })
    end

    def transfer_snapshot
      log_errors do
        logger.debug "Transfer thread start for #{snapshot_filename}"
        logger.debug "Transfering #{snapshot_filename} to S3"
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
      logger.debug "Posting #{s3_key} to application"
      request = EventMachine::HttpRequest.new(Mailroom.api_config["url"]).
        post(:body => {:bucket => AWS::S3::S3Object.current_bucket,
                       :key => s3_key},
             :head => {
               'authorization' => [Mailroom.api_config["username"], Mailroom.api_config["password"]]
             })
      request.callback do
        if request.response_header.http_status =~ /2\d\d/
          snapshot_posted
        else
          post_failed("Received a #{request.response_header.http_status} response")
        end
      end
      request.errback { post_failed(http.error) }
    end

    def snapshot_posted
      logger.info "Snapshot complete: #{s3_key}"
      deactivate!
    end

    def post_failed(reason)
      logger.error "Could not post snapshot: #{reason}"
      deactivate!
    end

    def log_errors
      begin
        yield
      rescue Exception => e
        Mailroom.notify(e)
        reset!
        deactivate!
        raise
      end
    end

    def s3_key
      File.join(S3_INBOX, File.basename(snapshot_filename))
    end
  end
end

`mkdir -p #{Mailroom::MailSpoolSnapshotter.temp_directory}`
