require 'nerve/ring_buffer'

module Nerve
  module ServiceCheck
    class BaseServiceCheck
      include Utils
      include Logging

      def initialize(opts={})
        @timeout = opts['timeout'] ? opts['timeout'].to_f : 0.1
        @rise    = opts['rise']    ? opts['rise'].to_i    : 1
        @fall    = opts['fall']    ? opts['fall'].to_i    : 1
        @name    = opts['name']    ? opts['name']         : "undefined"

        @check_buffer = RingBuffer.new([@rise, @fall].max)
        @last_result = nil
      end

      def up?
        # do the check
        check_result = !!catch_errors do
          check
        end

        # this is the first check -- initialize buffer
        if @last_result == nil
          @last_result = check_result
          @check_buffer.size.times {@check_buffer.push check_result}
          log.info "nerve: service check #{@name} initial check returned #{check_result}"
        end

        log.debug "nerve: service check #{@name} returned #{check_result}"
        @check_buffer.push(check_result)

        # we've failed if the last @fall times are false
        unless @check_buffer.last(@fall).reduce(:|)
          log.info "nerve: service check #{@name} transitions to down after #{@fall} failures" if @last_result
          @last_result = false
        end

        # we've succeeded if the last @rise times is true
        if @check_buffer.last(@rise).reduce(:&)
          log.info "nerve: service check #{@name} transitions to up after #{@rise} successes" unless @last_result
          @last_result = true
        end

        # otherwise return the last result
        return @last_result
      end

      def catch_errors(&block)
        begin
          return yield
        rescue Object => error
          log.info "nerve: service check #{@name} got error #{error.inspect}"
          return false
        end
      end
    end

    CHECKS ||= {}
    CHECKS['base'] = BaseServiceCheck
  end
end

