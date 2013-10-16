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

        # validate the voting conditions
        [@up, @down].each do |cond|
          raise ArgumentError, "Invalid condition #{cond['condition']} in machine check" \
            unless ['<', '<=', '>', '>='].include? cond['condition']
          cond['threshold'] = cond['threshold'].to_i
        end

        @buffer = RingBuffer.new(@hold)
        @no_idle = false

        log.debug "cpucheck initialized successfully"
      end

      def poll
        log.debug "polling cpuidle..."
        current_idle = get_idle
        log.debug "current_idle is #{current_idle}"
        @buffer.push current_idle
      end

      def vote_up?
        return @buffer.average.send(@up['condition'], @up['threshold'])
      end

      def vote_down?
        return @buffer.average.send(@down['condition'], @down['threshold'])
      end

      def vote
        if @buffer.include?(nil)
          log.debug "buffer is not filled. still #{@buffer.count{|i| i==nil}} empty elements"
          return 0
        end

        up = vote_up?
        down = vote_down?
        log.debug "upvote is #{up} and downvote is #{down}. Average is #{@buffer.average}"
        return 0 if up and down
        return 1 if up
        return -1 if down
        return 0
      end

      def get_idle
        metrics = []
        begin
          File.open('/proc/stat', 'r') do |f|
            metrics = f.readlines('/proc/stat')
          end
        rescue Errno::ENOENT
          log.warn "Cannot get CPU idle info; no /proc/stat" unless @no_idle
          @no_idle = true
          return 100
        rescue
          log.warn "Error reading /proc/stat"
          return 100
        end

        metrics = metrics.find{|line| line.slice(0,4) == "cpu "}.split
        metrics.shift
        metrics.map! {|e| e.to_i}

        idle = metrics[3]
        total = metrics.inject(:+)

        # we need to look at two metrics for instanteneous rather than cumulative
        # the returned idle is over the period from previous to this reading
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
          sleep 5
          return get_idle
        end
      end
    end

    CHECKS ||= {}
    CHECKS['cpuidle'] = CpuidleMachineCheck
  end
end
