module Nerve
  module VoterCheck
    class CpuidleVoterCheck

      def initialize(opts={})

        @exiting = false
        Thread.new(poll)
      end

      def poll
        while not @exiting
          
        end
      end

      def vote
      end

      def get_idle
        # TODO(mkr): check for non linux systems
        metrics = `cat /proc/stat | grep '^cpu '`.split
        metrics.shift
        metrics.map! {|e| e.to_i}
        idle = metrics[3]
        total = metrics.inject(:+)
        if @previous_total and @previous_idle
          diff_total = total - @previous_total
          diff_idle = idle - @previous_idle
          percent_usage = (100 * (diff_total - diff_idle.to_f) / diff_total).round(2)
          percent_idle = 100 - percent_usage
          @previous_total = total
          @previous_idle = idle
          return percent_idle
        else
          # otherwise, we haven't been called yet, so call ourselves...
          @previous_total = total
          @previous_idle = idle
          sleep 1
          return get_idle
        end
      end
    end
  end
end
