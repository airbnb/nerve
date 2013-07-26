module Nerve
  module Utils
    def safe_run(command)
      res = `#{command}`.chomp
      raise "command '#{command}' failed to run:\n#{res}" unless $?.success?
    end

    def ignore_errors(&block)
      begin
        return yield
      rescue Object => error
        log.debug "ignoring error #{error.inspect}"
        return false
      end
    end
  end
end
