require 'nerve/service_watcher/base'
require 'redis'

module Nerve
  module ServiceCheck
    class RedisServiceCheck < BaseServiceCheck

      def initialize(opts={})
        super

        @host = opts['host'] || '127.0.0.1'
        @port = opts ['port'] || 6379
        @db = opts['db'] || 0
        @name = "#{@db}@#{@host}:#{@port}"
      end

      def check
        log.debug "nerve: running @host = #{@host} health check #{@name}"

        begin
          redis = Redis.new(:host => @host, :port => @port, :db => @db)

          res = redis.ping

          if res.eql? 'PONG'
            return true
          else
            log.info "nerve: redis #{@name} failed to responde"
            return false
          end
        rescue Redis::BaseError => e
          log.info "nerve: unable to connect with redis #{@name} #{e}"
          return false
        ensure
          redis.quit if redis
        end
      end
    end

    CHECKS ||= {}
    CHECKS['redis'] = RedisServiceCheck
  end
end
