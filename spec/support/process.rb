require 'open3'

module Nerve
  module Test

    class Process
      attr_reader :command
      attr_reader :arguments
      attr_reader :working_directory
      attr_reader :environment

      attr_reader :pid
      attr_reader :name
      attr_reader :log

      attr_reader :stdout
      attr_reader :stderr

      class << self
        attr_accessor :log_by_default
      end
      @log_by_default = false

      def self.started
        @started ||= []
      end

      def self.stop_all
        started.dup.each { |p| p.stop }
      end

      def initialize(command, options={})
        @command = command
        @arguments = options[:arguments] || []
        @working_directory = options[:working_directory] || '.'
        @environment = environment || {}

        @name = options[:name] || command
        @log = options.fetch(:log, self.class.log_by_default)

        @stdout = ""
        @stderr = ""
      end

      def start
        raise "Already started" if @started
        @started = true
        clear_buffers

        log_print "Starting #{name}..."
        launch_process
        # start_consumer
        self.class.started << self
        log_puts " started! (pid=#{pid})"
      rescue => e
        log_puts " failed!"
        raise e
      end

      def stop(options={})
        return unless @started
        @started = false

        begin
          log_print "Stopping #{name} (pid=#{pid})..."
          send_signal(options[:signal] || :TERM)
          unless wait(options[:timeout] || 10)
            log_print " killing..."
            send_signal(:KILL)
          end
        rescue Errno::ESRCH, Errno::ECHILD
        end

        close_pipes

        self.class.started.delete(self)
        @pid = nil

        log_puts " stopped."
        @wait_thr.value
      end

      def wait(timeout=10)
        _pid = nil
        deadline = Time.now + timeout
        while deadline > Time.now
          _pid, status = ::Process.wait2(pid, ::Process::WNOHANG)
          break if _pid
        end
        !!_pid
      rescue Errno::ECHILD
        true
      ensure
        # stop_consumer
      end

      def clear_buffers
        @stdout.clear
        @stderr.clear
      end

      private

      def launch_process
        @stdin_p, @stdout_p, @stderr_p, @wait_thr =
          Open3.popen3(environment, command, *arguments,
            :chdir => working_directory)
        @pid = @wait_thr[:pid]
      end

      def close_pipes
        @stdin_p.close
        @stdout_p.close
        @stderr_p.close
      rescue => e
        puts "ERROR: exception while closing pipes: " \
          "#{e} #{e.backtrace.join("\n")}"
      end

      def send_signal(signal)
        ::Process.kill(signal, pid)
      end

      # def start_consumer
      #   @consuming = true
      #   @consumer_thr = Thread.new { consume_pipes }
      # end

      # def stop_consumer
      #   @consuming = false
      #   @consumer_thr.join
      #   @consumer_thr.kill
      # end

      # def consume_pipes
      #   read_atleast_once = false
      #   pipe_map = {
      #     @stdout_p => @stdout,
      #     @stderr_p => @stderr
      #   }

      #   while !read_atleast_once || @consuming
      #     loop do
      #       rs, _, _ = IO.select([@stdout_p, @stderr_p], [], [], 0.1)

      #       did_read = false
      #       rs.each do |p|
      #         string = p.read
      #         did_read = true if string && string.length > 0
      #         pipe_map[p] << string
      #       end

      #       read_atleast_once |= did_read
      #       break unless did_read
      #     end
      #   end

      # rescue => e
      #   puts "ERROR: exception in consumer: " \
      #     "#{e} #{e.backtrace.join("\n")}"
      # end

      def log_print(string)
        print string if log
      end

      def log_puts(string)
        puts string if log
      end

    end

  end
end