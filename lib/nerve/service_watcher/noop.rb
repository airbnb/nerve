require 'nerve/service_watcher/base'

module Nerve
  module ServiceCheck
    # ServiceCheck that checks nothing, but returns true.  Useful in scenarios
    # where you want the mere fact of nerve running to mean your node is
    # registered.
    class NoopServiceCheck < BaseServiceCheck
      def check
        true
      end
    end

    CHECKS ||= {}
    CHECKS['noop'] = NoopServiceCheck
  end
end
