module Nerve
  # RateLimiter implements a TokenBucket-based rate-limiting strategy.
  # It allows an average of `average_rate` tokens per `period`, with a
  # maximum burst of `max_burst` when the bucket is full.
  # `period` is the time period for `average_rate`, in seconds.
  # Note: a single instance of RateLimiter is *not* thread-safe.
  # See: https://en.wikipedia.org/wiki/Token_bucket
  class RateLimiter
    def initialize(average_rate: Float::INFINITY, max_burst: Float::INFINITY)
      raise ArgumentError, "average_rate should be numeric" unless average_rate.is_a? Numeric
      raise ArgumentError, "average_rate should be positive or zero" unless average_rate >= 0
      raise ArgumentError, "max_burst should be numeric" unless max_burst.is_a? Numeric
      raise ArgumentError, "max_burst should be >= 1" unless max_burst >= 1

      @average_rate = average_rate.to_f
      @max_burst = max_burst.to_f

      @tokens = @average_rate
      @last_refill = Time.now
    end

    # Consume a token, if one is available. Returns true if a token was consumed
    # and false otherwise. For a rate-limited action, the action should be
    # executed only when `consume` returns true.
    def consume
      return true unless @average_rate.finite?

      refill_tokens
      return false unless @tokens >= 1

      @tokens -= 1
      return true
    end

    private

    def refill_tokens
      now = Time.now
      elapsed = now - @last_refill
      delta_tokens = (@average_rate * elapsed).floor
      return nil unless delta_tokens >= 1

      @tokens = [@tokens + delta_tokens, @max_burst].min
      @last_refill = now
    end
  end
end
