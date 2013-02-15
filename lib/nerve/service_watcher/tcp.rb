require_relative './base'

module Nerve
  module ServiceCheck
    require 'socket'

    class TcpServiceCheck < BaseServiceCheck
      def initialize(opts={})
        super

        raise ArgumentError unless opts['port']

        @port = opts['port']
        @host = opts['host'] || '127.0.0.1'
        @name = "tcp-#{@host}:#{@port}"
      end

      def check
        log.debug "running health check #{@name}"

        begin
          socket = TCPSocket.new(@host,@port)
        rescue
          return false
        ensure
          socket.close
        end

        return true
      end
    end

    CHECKS ||= {}
    CHECKS['tcp'] = TcpServiceCheck
  end
end
