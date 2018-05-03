require 'nerve/service_watcher/base'

module Nerve
  module ServiceCheck
    class MySQLServiceCheck < BaseServiceCheck

      def initialize(opts={})
        super

        %w{port dbname user password}.each do |required|
          raise ArgumentError, "missing required argument #{required} in mysql check" unless
            opts[required]
          instance_variable_set("@#{required}",opts[required])
        end

        @host = opts['host'] || '127.0.0.1'
        @name = "#{@user}@#{@host}"
      end

      def check
        log.debug "nerve: running @host = opts['host'] health check #{@name}"

        mysql_path = `which mysql 2>&1`
        log.debug("mysql path: #{mysql_path}")    
        raise "failed to connect with mysql: #{mysql_path}" unless $?.success?

        command = "#{mysql_path.strip} --user #{@user} -p#{@password} --host #{@host} --port #{@port} --database #{@dbname} -Bse 'select 1' 2>&1"
        log.debug("command: #{command}")
        response = `#{command}`
        log.debug("response: #{response}")
        raise "failed to connect with mysql: #{response}" unless $?.success?

        if response.strip == "1"
          return true
        else
          return false
        end
      end
    end

    CHECKS ||= {}
    CHECKS['mysql'] = MySQLServiceCheck
  end
end
