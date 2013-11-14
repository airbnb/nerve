require 'nerve/service_watcher/base'
require 'pg'

module Nerve
  module ServiceCheck
    class PostgreSQLServiceCheck < BaseServiceCheck
      require 'socket'
      include Socket::Constants

      def initialize(opts={})
        super

        raise ArgumentError, "missing required arguments in postgresql check" unless opts['port'] and opts['user']

        @port = opts['port']
        @host = opts['host']
        @dbname = opts['dbname']
        @user = opts['user']
        @password = opts['password']
      end

      def check
        # The best way to check postgresql is alive to query
        log.debug "nerve: running @host = opts['host'] health check #{@name}"

        conn = PGconn.new(
          :host => @host,
          :port => @port,
          :dbname => @dbname,
          :user => @user,
          :password => @password
        )

        begin
          res = conn.exec('select 1')
          data = res.getvalue(0,0)
          if data
            return true
          else
            log.debug "nerve: postgresql failed to responde"
            return false
          end
        ensure
          conn.close
        end
      end
    end

    CHECKS ||= {}
    CHECKS['postgresql'] = PostgreSQLServiceCheck
  end
end
