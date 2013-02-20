require_relative './base'

module Nerve
  module ServiceCheck
    require 'net/http'

    class HttpServiceCheck < BaseServiceCheck
      def initialize(opts={})
        super

        %w{port uri}.each do |required|
          raise ArgumentError, "you need to specify required argument #{required}" unless
            opts[required]
          instance_variable_set("@#{required}",opts[required])
        end

        @host = opts['host'] || '127.0.0.1'
        @name = "http-#{@host}:#{@port}#{@uri}"
        @ssl = (opts.include?('ssl')) ? opts['ssl'] : false
      end

      def check
        log.debug "running health check #{@name}"

        connection = Net::HTTP.new(@host,@port)
        if @ssl
          connection.use_ssl = true
          connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        response = connection.get(@uri)

        log.debug "check #{@name} got response code #{response.code}"
        return true if (response.code.to_i >= 200 && response.code.to_i < 300)
        return false
      end
    end

    CHECKS ||= {}
    CHECKS['http'] = HttpServiceCheck
  end
end
