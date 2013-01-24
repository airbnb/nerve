module Nerve
  module ServiceCheck
    require 'net/http'

    class HttpServiceCheck
      include Utils
      include Logging
      def initialize(opts={})
        %w{port uri}.each do |required|
          raise ArgumentError, "you need to specify required argument #{required}" unless
            opts[required]
          instance_variable_set("@#{required}",opts[required])
        end

        @host = opts['host'] || '0.0.0.0'
        @timeout = opts['timeout'] || 0.1
      end

      def check?
        name = "#{@host}:#{@port}#{@uri}"
        log.debug "running health check #{name}"

        # ignore all errors
        return_status = ignore_errors do
          Timeout::timeout(@timeout) do
            connection = Net::HTTP.start(@host,@port)
            response = connection.get(@uri)

            log.debug "check #{name} got response code #{response.code}"
            return true if response.code.to_i >= 200 && response.code.to_i < 300
            return false
          end
        end

        log.debug "check #{name} returned #{return_status}"
        return return_status
      end
    end

    CHECKS ||= {}
    CHECKS['http'] = HttpServiceCheck
  end
end
