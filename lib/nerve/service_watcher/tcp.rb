require 'nerve/service_watcher/base'

module Nerve
  module ServiceCheck
    class TcpServiceCheck < BaseServiceCheck
      require 'socket'
      include Socket::Constants

      def initialize(opts={})
        super

        raise ArgumentError, "missing required argument 'port' in tcp check" unless opts['port']

        @port = opts['port']
        @host = opts['host'] || '127.0.0.1'

        @address = Socket.sockaddr_in(@port, @host)
      end

      def check
        log.debug "nerve: running TCP health check #{@name}"

        # create a TCP socket
        socket = Socket.new(AF_INET, SOCK_STREAM, 0)

        begin
          # open a non-blocking connection
          socket.connect_nonblock(@address)
        rescue Errno::EINPROGRESS
          # opening a non-blocking socket will usually raise
          # this exception. it's just connect returning immediately,
          # so it's not really an exception, but ruby makes it into
          # one. if we got here, we are now free to wait until the timeout
          # expires for the socket to be writeable
          IO.select(nil, [socket], nil, @timeout)

          # we should be connected now; allow any other exception through
          begin
            socket.connect_nonblock(@address)
          rescue Errno::EISCONN
            return true
          end
        else
          # we managed to connect REALLY REALLY FAST
          log.debug "nerve: connected to non-blocking socket without an exception"
          return true
        ensure
          socket.close
        end
      end
    end

    CHECKS ||= {}
    CHECKS['tcp'] = TcpServiceCheck
  end
end
