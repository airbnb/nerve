module Nerve
  module ServiceCheck
    require 'socket'

    class TcpServiceCheck
      include Base
      include Logging
      def initialize(opts={})
        raise ArgumentError unless opts['port']
        @port = opts['port']
        @host = opts['host'] ? opts['host'] : '0.0.0.0'
      end

      def check?
        log.debug "making tcp connection to #{@host.inspect} and #{@port.inspect}"
        # catch all errors
        return_status = ignore_errors do
          # TODO(mkr): add a timeout
          Timeout::timeout(0.1) do
            socket = TCPSocket.new(@host,@port)
            socket.close
          end
        end
        return return_status
      end
    end

    CHECKS ||= {}
    CHECKS['tcp'] = TcpServiceCheck
  end
end
