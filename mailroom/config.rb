module Mailroom
  module Config
    extend self

    def self.config_hash
      @hash ||= YAML.load_file(File.join(Mailroom.root, "config.yml"))
    end

    def self.configuration(name, options = {}, &transform)
      define_method name do
        raw = Config.config_hash[(options[:key] || name).to_s] || options[:default]
        if transform
          transform.call(raw)
        else
          raw
        end
      end
    end

    configuration :api_config, :default => {}, :key => :api
    configuration :s3config, :default => {}, :key => :s3 do |s3hash|
      s3hash.inject({}) { |h, t| h.merge(t[0].to_sym => t[1])}.
        merge(:pool_size => EventMachine.threadpool_size)
    end
    configuration :mail_spools, :default => []
    configuration :airbrake_key
    configuration :temp_directory, :default => "/tmp/mailroom"
    configuration :s3_inbox, :default => "/mailroom/mbox/incoming"
    configuration :log_level, :default => "INFO" do |s| s.upcase end
    configuration :pid_directory, :default => "/var/run"
  end
end
