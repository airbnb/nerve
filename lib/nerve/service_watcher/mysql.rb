require 'nerve/service_watcher/base'
require 'mysql'

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

        begin
          conn = Mysql.new(
            @host, 
            @user, 
            @password, 
            @dbname, 
            @port
          )

          res = conn.query 'SELECT VERSION()'
          data = res.fetch_row

          if data
            return true
          else
            log.debug "nerve: mysql failed to responde"
            return false
          end
        rescue Mysql::Error => e
          log.debug "nerve: unable to connect with mysql #{e}"
          return false
        ensure
          conn.close if conn
        end
      end
    end

    CHECKS ||= {}
    CHECKS['mysql'] = MySQLServiceCheck
  end
end
