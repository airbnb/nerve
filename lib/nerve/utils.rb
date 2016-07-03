module Nerve
  module Utils
    def safe_run(command)
      res = `#{command}`.chomp
      raise "command '#{command}' failed to run:\n#{res}" unless $?.success?
    end

    def responsive_sleep(seconds)
      nap_time = seconds
      while nap_time > 0
        yield if block_given?
        sleep [nap_time, 1].min
        nap_time -= 1
      end
    end
  end
end
