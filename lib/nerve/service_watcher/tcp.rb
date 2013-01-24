module Nerve
  module ServiceCheck
    require 'socket'

    class TcpServiceCheck
      include Base
      include Logging
      def initialize(opts={})
        raise ArgumentError unless opts['port']

        @port = opts['port']
        @host = opts['host'] || '0.0.0.0'
        @timeout = opts['timeout'] || 0.1
      end

      def check?
        name = "#{@host}:#{@port}"
        log.debug "making tcp connection to #{name}"

        # catch all errors
        return_status = ignore_errors do
          Timeout::timeout(@timeout) do
            socket = TCPSocket.new(@host,@port)
            socket.close
            return True
          end
        end

        log.debug "tcp check #{name} returned #{return_status}"
        return return_status
      end
    end

    CHECKS ||= {}
    CHECKS['tcp'] = TcpServiceCheck
  end
end
