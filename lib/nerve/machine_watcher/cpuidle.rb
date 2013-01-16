module Nerve
  module MachineCheck
    class CpuidleMachineCheck
      include Logging
      def initialize(opts={})
        log.debug "creating machine check"
        %w{hold up down}.each do |required|
          raise ArgumentError, "you need to provide #{required}" unless opts[required]
          instance_variable_set("@#{required}",opts[required])
        end

        @exiting = false
        Thread.new{poll}
        log.debug "returning from cpuidle check init"
      end

      def poll
        log.debug "creating polling thread"
        # keep the last hold time of info
        @buffer = RingBuffer.new(@hold)
        until defined?(EXIT)
          @buffer.push get_idle
          sleep 1
        end
      end

      def vote_up?
        # TODO(mkr): verify this works ok. it should.
        eval %{ #{@buffer.average} #{@up.condition} #{@up.threshold} }
      end

      def vote_down?
        # TODO(mkr): verify this works ok. it should.
        eval %{ #{@buffer.average} #{@down.condition} #{@down.threshold} }
      end

      def vote
        return 0 unless @bufffer and @buffer.size == @hold
        up = vote_up?
        down = vode_down?
        return 0 if up and down
        return 1 if up
        return -1 if down
        return 0
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
          sleep 0.1
          return get_idle
        end
      end

    end
  end
end
