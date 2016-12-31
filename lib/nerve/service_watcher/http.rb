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
        @http_port  = opts['http_port']  || @port
        @headers     = opts['headers'] || {}

        @expect      = opts['expect']

        @name        = "http-#{@host}:#{@http_port}#{@uri}"
      end

      def check
        log.debug "running health check #{@name}"

        connection = get_connection
        response = connection.get(@uri, @headers)
        code = response.code.to_i
        body = response.body

        # Any 2xx or 3xx code should be considered healthy. This is standard
        # practice in HAProxy, nginx, etc ...
        if code >= 200 and code < 400 and (@expect == nil || body.include?(@expect))
          log.debug "nerve: check #{@name} got response code #{code} with body \"#{body}\""
          return true
        else
          log.warn "nerve: check #{@name} got response code #{code} with body \"#{body}\""
          return false
        end
      end

      private
      def get_connection
        con = Net::HTTP.new(@host, @http_port)
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
