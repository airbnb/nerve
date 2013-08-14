require_relative './base'
require 'bunny'

module Nerve
  module ServiceCheck
    class RabbitMQServiceCheck < BaseServiceCheck
      require 'socket'
      include Socket::Constants

      def initialize(opts={})
        super

        raise ArgumentError, "missing required argument 'port' in rabbitmq check" unless opts['port']

        @port = opts['port']
        @host = opts['host']     || '127.0.0.1'
        @user = opts['username'] || 'guest'
        @pass = opts['password'] || 'guest'
      end

      def check
        # the idea for this check was taken from the one in rabbitmq management
        #  -- the aliveness_test:
        # https://github.com/rabbitmq/rabbitmq-management/blob/9a8e3d1ab5144e3f6a1cb9a4639eb738713b926d/src/rabbit_mgmt_wm_aliveness_test.erl
        log.debug "nerve: running rabbitmq health check #{@name}"

        conn = Bunny.new(
          :host => @host,
          :port => @port,
          :user => @user,
          :pass => @pass,
          :log_file => STDERR,
          :continuation_timeout => @timeout,
          :automatically_recover => false,
          :heartbeat => false,
          :threaded => false
        )

        begin
          conn.start
          ch = conn.create_channel

          # create a queue, publish to it
          log.debug "nerve: publishing to rabbitmq"
          ch.queue('nerve')
          ch.basic_publish('nerve test message', '', 'nerve', :mandatory => true, :expiration => 2 * 1000)

          # read and ack the message
          log.debug "nerve: consuming from rabbitmq"
          delivery_info, properties, payload = ch.basic_get('nerve', :ack => true)

          if payload:
            ch.acknowledge(delivery_info.delivery_tag)
            return true
          else
            log.debug "nerve: rabbitmq consumption returned no payload"
            return false
          end
        ensure
          conn.close
        end
      end
    end

    CHECKS ||= {}
    CHECKS['rabbitmq'] = RabbitMQServiceCheck
  end
end
