require 'nerve/service_watcher/base'

module Nerve
  module ServiceCheck
    class MysqlServiceCheck < BaseServiceCheck
      require 'mysql2'

      def initialize(opts={})
        super

        raise ArgumentError, "missing required argument 'user' in mysql check" unless opts['user']

        @user = opts['user']
        @pass = opts['password'] || ''
        @host = opts['host'] || '127.0.0.1'
        @port = opts['port'] || '3306'
      end

      def check
        # the idea of health check is similar to haproxy option mysql-check
        log.debug "nerve: running mysql health check #{@name}"

        begin
          log.debug "nerve: mysql connect #{@host}:#{@port} as #{@user}"
          conn = Mysql2::Client.new(:host => @host, :username => @user, :password => @pass, :port => @port)
        rescue Mysql2::Error => e
          log.debug "nerve: mysql check error #{e.errno}: #{e.error}"
          return false
        ensure
          conn.close if conn
        end

        return true
      end
    end

    CHECKS ||= {}
    CHECKS['mysql'] = MysqlServiceCheck
  end
end
