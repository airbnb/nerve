require 'datadog/statsd'
require 'nerve/log'

module Nerve
  module StatsD
    def statsd
      @@STATSD = StatsD.statsd_for(self.class.name) unless !@@STATSD_RELOAD && @@STATSD
      @@STATSD_RELOAD = false
      @@STATSD
    end

    class << self
      include Logging

      @@STATSD_HOST = "localhost"
      @@STATSD_PORT = 8125
      @@STATSD_RELOAD = true

      def statsd_for(classname)
        log.debug "nerve: creating statsd client for class '#{classname}' on host '#{@@STATSD_HOST}' port #{@@STATSD_PORT}"
        Datadog::Statsd.new(@@STATSD_HOST, @@STATSD_PORT)
      end

      def configure_statsd(opts)
        @@STATSD_HOST = opts['host'] || @@STATSD_HOST
        @@STATSD_PORT = (opts['port'] || @@STATSD_PORT).to_i
        @@STATSD_RELOAD = true
        log.info "nerve: configuring statsd on host '#{@@STATSD_HOST}' port #{@@STATSD_PORT}"
      end
    end
  end
end
