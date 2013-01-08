module Nerve
  module VoterCheck
    class CpuidleVoterCheck

      def initialize(opts={})
        # TODO(mkr): proper input validation
        @hold = opts['hold']
        @up = opts['up']
        @down = opts['down']
        
        @exiting = false
        Thread.new(poll)
      end

      def poll
        # keep the last hold time of info
        @buffer = RingBuffer.new(@hold)
        while not @exiting
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

      class RingBuffer < Array
        alias_method :array_push, :push
        alias_method :array_element, :[]
        
        def initialize( size )
          @ring_size = size
          super( size )
        end

        def average
          self.inject(0.0) { |sum, el| sum + el } / self.size
        end
        
        def push( element )
          if length == @ring_size
            shift # loose element
          end
          array_push element
        end
        
        # Access elements in the RingBuffer
        #
        # offset will be typically negative!
        #
        def []( offset = 0 )
          return self.array_element( - 1 + offset )
        end
      end
    end
  end
end
