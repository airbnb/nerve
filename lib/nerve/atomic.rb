require 'thread'

module Nerve
  class AtomicValue
    def initialize(initial_value=nil)
      @mu = Mutex.new
      set(initial_value)
    end

    def get
      return @mu.synchronize { @value }
    end

    def set(new_value)
      @mu.synchronize {
        @value = new_value
      }
    end
  end
end
