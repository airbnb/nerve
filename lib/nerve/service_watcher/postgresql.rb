require 'nerve/service_watcher/base'

module Nerve
  module ServiceCheck
    class PostgreSQLServiceCheck < BaseServiceCheck

      def initialize(opts={})
        super

        %w{port dbname user password}.each do |required|
          raise ArgumentError, "missing required argument #{required} in postgresql check" unless
            opts[required]
          instance_variable_set("@#{required}",opts[required])
        end

        @host = opts['host'] || '127.0.0.1'
        @name = "#{@user}@#{@host}"
      end

      def check
        # The best way to check postgresql is alive to query
        log.debug "nerve: running @host = opts['host'] health check #{@name}"

        psql_path = `which psql 2>&1`
        log.debug("psql path: #{psql_path}")    
        raise "failed to connect with postgres: #{psql_path}" unless $?.success?

        command = "#{psql_path.strip} --host #{@host} --port #{@port} --user #{@user} --dbname #{@dbname} -c 'select 1' --tuples-only"
        log.debug("command: #{command}")
        response = `#{command}`
        log.debug("response: #{response}")
        raise "failed to connect with psql: #{response}" unless $?.success?

        if response.strip == "1"
          return true
        else
          return false
        end
      end
    end

    CHECKS ||= {}
    CHECKS['postgresql'] = PostgreSQLServiceCheck
  end
end
