module Nerve
  module ServiceCheck
    require 'net/http'

    class HttpServiceCheck
      include Logging
      def initialize(opts={})
        %w{port uri}.each do |required|
          raise ArgumentError, "you need to specify required argument #{required}" \
            unless opts[required]
          instance_variable_set("@#{required}",opts[required])
        end
        @host = opts['host'] ? opts['host'] : '0.0.0.0'
      end

      def check?
        # catch all errors
        log.debug "making http connection to #{@host.inspect} and #{@port.inspect} at #{@uri.inspect}"
        begin
          # TODO(mkr): add a timeout
          connection = Net::HTTP.start(@host,@port)
          response = connection.get(@uri)
          # TODO(mkr): add a good output message
          unless (response.code.to_i >= 200 && response.code.to_i < 300)
            log.debug "response code was not a 200"
            return false
          end
        rescue Object => e
          log.debug "caught error"
          return false
        end
        log.debug "health check passed"
        return true
      end
    end
  end
end
