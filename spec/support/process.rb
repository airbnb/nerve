require 'open3'

module Nerve
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
    attr_reader :status

    class << self
      attr_accessor :log_by_default
    end
    @log_by_default = false

    def self.started_processes
      @@started_processes ||= []
    end

    def self.stop_all(options={})
      started_processes.dup.each { |p| p.stop(options) }
    end

    def initialize(command, options={})
      @command = command
      @arguments = options[:arguments] || []
      @working_directory = options[:working_directory] || '.'
      @environment = options[:environment] || {}

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
      start_consumer
      self.class.started_processes << self
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
        unless wait(:timeout => options[:timeout] || 10)
          log_print " killing..."
          send_signal(:KILL)
        end
      rescue Errno::ESRCH, Errno::ECHILD
      end

      close_pipes

      self.class.started_processes.delete(self)
      @pid = nil

      log_puts " stopped."
      @status
    end

    def restart(options={})
      stop(options)
      start
    end

    def running?
      @wait_thr.alive?
    end

    def wait(options={})
      timeout = options[:timeout] || 10
      deadline = Time.now + timeout
      sleep 0.1 while deadline > Time.now && running?
      running?
    rescue Errno::ECHILD
      true
    ensure
      unless running?
        stop_consumer
        @status = @wait_thr.value
      end
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

    def start_consumer
      @consumer_thr = Thread.new do
        consume_pipes(@wait_thr)
      end
    end

    def stop_consumer
      @consumer_thr.join
    end

    def consume_pipes(wait_thread)
      pipe_map = {
        @stdout_p => @stdout,
        @stderr_p => @stderr
      }
      until pipe_map.empty?
        rs, _, _ = IO.select([@stdout_p, @stderr_p], nil, nil, nil)
        rs.each do |p|
          begin
            pipe_map[p] << p.read_nonblock(1024)
          rescue EOFError
            pipe_map.delete(p)
          end
        end
      end
    rescue => e
      puts "ERROR: exception in consumer: " \
        "#{e} #{e.backtrace.join("\n")}"
    end

    def log_print(string)
      print string if log
    end

    def log_puts(string)
      puts string if log
    end
  end
end

require 'support/process/nerve'
require 'support/process/zookeeper'
