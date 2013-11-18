require 'nerve/service_watcher/base'
require 'pg'

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

        begin
          conn = PGconn.new(
                    :host => @host,
                    :port => @port,
                    :dbname => @dbname,
                    :user => @user,
                    :password => @password
                  )

          res = conn.exec('select 1')
          data = res.getvalue(0,0)
          if data
            return true
          else
            log.debug "nerve: postgresql failed to responde"
            return false
          end
        rescue PG::Error => e
          log.debug "nerve: unable to connect with postgresql #{e}"
          return false
        ensure
          conn.close if conn
        end
      end
    end

    CHECKS ||= {}
    CHECKS['postgresql'] = PostgreSQLServiceCheck
  end
end
