module Nerve
  module Base
    # def log(message)
    #   @@log = Logger.new STDOUT unless defined?(@@log)
    #   @@log.debug message
    # end

    def safe_run(command)
      res = `#{command}`.chomp
      raise "command '#{command}' failed to run:\n#{res}" unless $?.success?
    end

    def ignore_errors(&block)
      begin
        yield
      rescue Object => error
        log.debug "ignoring error #{error.inspect}"
        return false
      end
      return true
    end

    def retry_this(retry_times=3, &block)
      retries = 0
      begin
        yield
      rescue Object => e
        if retries < retry_times
          log.error "zk_helper encountered an error: #{e.inspect}"
          log.error "waiting a sec, then retrying..."
          sleep 1
          retries += 1
          retry
        else
          log.error "zk_helper encountered a fatal error:"
          log.error e.inspect
          log.error e.backtrace
          raise e
        end
      end
    end

  end
end
