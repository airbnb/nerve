require 'spec_helper'
require 'nerve/rate_limiter'
require 'active_support/all'
require 'active_support/testing/time_helpers'

AVERAGE_RATE = 100
MAX_BURST = 500
PERIOD = 1

describe Nerve::RateLimiter do
  include ActiveSupport::Testing::TimeHelpers

  describe 'initialize' do
    it 'can successfully initialize without a period' do
      Nerve::RateLimiter.new(average_rate: AVERAGE_RATE, max_burst: MAX_BURST)
    end

    it 'can successfully initialize with a period' do
      Nerve::RateLimiter.new(average_rate: AVERAGE_RATE, max_burst: MAX_BURST, period: PERIOD)
    end
  end

  describe 'consume' do
    let!(:rate_limiter) {
      Nerve::RateLimiter.new(average_rate: AVERAGE_RATE, max_burst: MAX_BURST, period: PERIOD)
    }

    context 'when no tokens have been consumed' do
      it 'allows tokens to be consumed' do
        expect(rate_limiter.consume).to be true
      end

      it 'allows up to the maximum burst' do
        # Wait until there are enough tokens to hit the maximum burst
        travel (MAX_BURST / AVERAGE_RATE + 1) * PERIOD

        for _ in 1..MAX_BURST do
          expect(rate_limiter.consume).to be true
        end
      end

      it 'does not allow more than the maximum burst' do
        # Wait until there are enough tokens to hit the maximum burst
        travel (MAX_BURST / AVERAGE_RATE + 1) * PERIOD

        for _ in 1..MAX_BURST do
          rate_limiter.consume
        end

        expect(rate_limiter.consume).to be false
      end
    end

    context 'when all tokens are consumed' do
      before {
        # consume up to the maximum burst
        for _ in 1..MAX_BURST do
          rate_limiter.consume
        end
      }

      it 'does not allow tokens to be consumed' do
        expect(rate_limiter.consume).to be false
      end

      it 'allows tokens to be consumed next period' do
        travel PERIOD
        expect(rate_limiter.consume).to be true
      end
    end

    it 'only allows average rate over time' do
      start_time = Time.now
      count_success = 0
      num_periods = 250

      # Freeze time unless we manually move it.
      travel_to start_time

      # Clear all existing tokens.
      while rate_limiter.consume do end

      for period in 1..num_periods do
        travel PERIOD

        while rate_limiter.consume
          count_success += 1
        end

        # Only check the average rate after a while, in which the rate will have
        # been sustained enough to have an accurate average.
        if period >= 0.1 * num_periods
          elapsed_time = Time.now - start_time
          avg_rate = count_success / elapsed_time
          expect(avg_rate).to be_within(0.05 * AVERAGE_RATE).of AVERAGE_RATE
        end
      end
    end
  end
end
