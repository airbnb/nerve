require 'nerve/service_watcher/base'

module Nerve
  module ServiceCheck
    class RedisServiceCheck < BaseServiceCheck
      require 'redis'

      def initialize(opts={})
        super
        raise ArgumentError, "missing required argument 'port' in redis check" unless opts['port']
        @port = opts['port']
        @host = opts['host'] || '127.0.0.1'
      end

      def check
        log.debug "nerve: running redis health check #{@name}"
        begin
          redis = Redis.new(host: @host, port: @port, timeout: @timeout)
          redis.ping
          # Ensure underlying host is available if proxying
          redis.exists('nerve-redis-service-check')
          return true
        ensure
          redis.close if redis
        end
      end
    end

    CHECKS ||= {}
    CHECKS['redis'] = RedisServiceCheck
  end
end
