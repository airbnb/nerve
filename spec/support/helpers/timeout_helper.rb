module TimeoutHelper

  # This module will keep retrying a failing operation until it either succeeds
  # or the time limit is exceeded. Once the timeout is reached, the final
  # exception will bubble up. This is intended to be used to catch RSpec
  # expectation exceptions, retrying the expectationion until time runs out.

  def until_timeout(timeout=1, message=nil, options={})
    deadline = Time.now + timeout
    begin
      yield
    rescue => e
      raise Timeout::Error.new("#{e}: #{message}") if Time.now > deadline
      sleep options[:sleep_wait] || 0.1
      retry
    end
  end

end