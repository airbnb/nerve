module Nerve
  module ServiceCheck
    require 'net/http'
    
    class HttpServiceCheck
      def initialize(opts={})
        raise ArgumentError unless opts['port']
        raise ArgumentError unless opts['uri']
        @port = opts['port']
        @uri = opts['uri']
        @host = opts['host'] ? opts['host'] : '0.0.0.0'
      end

      def check
        # catch all errors
        begin
          connection = Net::HTTP.start(@host,@port)
          response = connection.get(@uri)
          # TODO(mkr): add a good output message
          return false unless response.code >= 200 && response.code < 300
        rescue
          # TODO(mkr): add a good output message
          return false
        end
        return true
      end
    end
  end
end
