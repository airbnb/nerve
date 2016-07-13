module Nerve
  module Utils
    def safe_run(command)
      res = `#{command}`.chomp
      raise "command '#{command}' failed to run:\n#{res}" unless $?.success?
    end

    def responsive_sleep(seconds, tick=1, &should_exit)
      nap_time = seconds
      while nap_time > 0
        break if (should_exit && should_exit.call)
        sleep [nap_time, tick].min
        nap_time -= tick
      end
    end
  end
end
