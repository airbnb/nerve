module Nerve
  module ServiceCheck
    require 'net/http'

    class HttpServiceCheck
      include Base
      include Logging
      def initialize(opts={})
        %w{port uri}.each do |required|
          raise ArgumentError, "you need to specify required argument #{required}" unless
            opts[required]
          instance_variable_set("@#{required}",opts[required])
        end
        @host = opts['host'] ? opts['host'] : '0.0.0.0'
      end

      def check?
        # ignore all errors
        return_status = ignore_errors do
          Timeout::timeout(0.1) do
            connection = Net::HTTP.start(@host,@port)
            response = connection.get(@uri)
            unless (response.code.to_i >= 200 && response.code.to_i < 300)
              log.debug "response code was not a 200"
              return false
            end
            return true
          end
        end
        log.debug "health check was #{return_status}"
        return return_status
      end

    end
  end
end
