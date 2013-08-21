require 'nerve/service_watcher/base'

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

        @host        = opts['host'] || '127.0.0.1'
        @ssl         = opts['ssl']  || false

        @read_timeout = opts['read_timeout'] || @timeout
        @open_timeout = opts['open_timeout'] || 0.2
        @ssl_timeout  = opts['ssl_timeout']  || 0.2

        @name        = "http-#{@host}:#{@port}#{@uri}"
      end

      def check
        log.debug "running health check #{@name}"

        connection = get_connection
        response = connection.get(@uri)
        code = response.code.to_i

        log.debug "nerve: check #{@name} got response code #{code}"
        if code >= 200 and code < 300
          return true
        else
          return false
        end
      end

      private
      def get_connection
        con = Net::HTTP.new(@host, @port)
        con.read_timeout = @read_timeout
        con.open_timeout = @open_timeout

        if @ssl
          con.use_ssl = true
          con.ssl_timeout = @ssl_timeout
          con.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        return con
      end

    end

    CHECKS ||= {}
    CHECKS['http'] = HttpServiceCheck
  end
end
