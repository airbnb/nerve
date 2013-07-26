require_relative './base'

module Nerve
  module ServiceCheck
    require 'net/http'

    class HttpServiceCheck < BaseServiceCheck
      def initialize(opts={})
        super

        %w{port uri}.each do |required|
          raise ArgumentError, "missing required argument #{required} in http check" unless
            opts[required]
          instance_variable_set("@#{required}",opts[required])
        end

        @name        = "http-#{@host}:#{@port}#{@uri}"
        @host        = opts['host'] || '127.0.0.1'
        @ssl         = opts['ssl']  || false

        @read_timeout = opts['read_timeout'] || @timeout
        @open_timeout = opts['open_timeout'] || 0.2
        @ssl_timeout  = opts['ssl_timeout']  || 0.2

        @args = {:read_timeout => @read_timeout, :open_timeout => @open_timeout, :ssl_timeout => @timeout}
      end

      def check
        log.debug "running health check #{@name}"

        connection = get_connection
        begin
          response = connection.get(@uri)

          log.debug "nerve: check #{@name} got response code #{response.code}"
          return true if (response.code.to_i >= 200 && response.code.to_i < 300)
          return false
        ensure
          connection.finish
        end
      end

      private
      def get_connection
        c = Net::HTTP.start(@host, @port, @args)
        if @ssl
          connection.use_ssl = true
          connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        c
      end

    end

    CHECKS ||= {}
    CHECKS['http'] = HttpServiceCheck
  end
end
