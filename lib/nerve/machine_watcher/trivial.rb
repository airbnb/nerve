module Nerve
  module MachineCheck
    class TrivialCheck
      include Logging

      def initialize(opts={})
      end

      def poll
      end

      def vote
        0
      end
    end

    CHECKS ||= {}
    CHECKS['trivial'] = TrivialCheck
  end
end