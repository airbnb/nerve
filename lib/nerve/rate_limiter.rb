module Nerve
  # RateLimiter implements a TokenBucket-based rate-limiting strategy.
  # It allows an average of `average_rate` tokens per `period`, with a
  # maximum burst of `max_burst` when the bucket is full.
  # `period` is the time period for `average_rate`, in seconds.
  # Note: a single instance of RateLimiter is *not* thread-safe.
  # See: https://en.wikipedia.org/wiki/Token_bucket
  class RateLimiter
    def initialize(average_rate:, max_burst:, period: 1)
      raise TypeError, "average_rate should be numeric" unless average_rate.is_a? Numeric
      raise TypeError, "max_burst should be numeric" unless max_burst.is_a? Numeric
      raise TypeError, "period should be numeric" unless period.is_a? Numeric

      @average_rate = average_rate
      @max_burst = max_burst
      @period = period

      @tokens = @average_rate
      @last_refill = Time.now
    end

    # Consume a token, if one is available. Returns true if a token was consumed
    # and false otherwise. For a rate-limited action, the action should be
    # executed only when `consume` returns true.
    def consume
      refill_tokens
      return false unless @tokens >= 1

      @tokens -= 1
      return true
    end

    private

    def refill_tokens
      now = Time.now
      elapsed = (now - @last_refill).to_f / @period
      delta_tokens = (@average_rate * elapsed).floor
      return nil unless delta_tokens >= 1

      @tokens = [@tokens + delta_tokens, @max_burst].min
      @last_refill = now
    end
  end
end
