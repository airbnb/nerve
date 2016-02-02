require 'yaml'
require 'optparse'

module Nerve
  class ConfigurationManager
    attr_reader :config

    def parse_options!
      options = {}
      # set command line options
      optparse = OptionParser.new do |opts|
        opts.banner =<<EOB
Welcome to nerve

Usage: nerve --config /path/to/nerve/config
EOB

        options[:config] = ENV['NERVE_CONFIG']
        opts.on('-c config','--config config', String, 'path to nerve config') do |key,value|
          options[:config] = key
        end

        options[:instance_id] = ENV['NERVE_INSTANCE_ID']
        opts.on('-i instance_id','--instance_id instance_id', String,
          'reported as `name` to ZK; overrides instance id from config file') do |key,value|
          options[:instance_id] = key
        end

        opts.on('-h', '--help', 'Display this screen') do
          puts opts
          exit
        end
      end
      optparse.parse!
      @options = options
      @options
    end

    def generate_nerve_config(options)
      config = parse_config_file(options[:config])
      config['services'] ||= {}

      if config.has_key?('service_conf_dir')
        cdir = File.expand_path(config['service_conf_dir'])
        if ! Dir.exists?(cdir) then
          raise "service conf dir does not exist:#{cdir}"
        end
        cfiles = Dir.glob(File.join(cdir, '*.{yaml,json}'))
        cfiles.each { |x| config['services'][File.basename(x[/(.*)\.(yaml|json)$/, 1])] = parse_config_file(x) }
      end

      if options[:instance_id] && !options[:instance_id].empty?
        config['instance_id'] = options[:instance_id]
      end

      config
    end

    def parse_config_file(filename)
      # parse nerve config file
      begin
        c = YAML::parse(File.read(filename))
      rescue Errno::ENOENT => e
        raise ArgumentError, "config file does not exist:\n#{e.inspect}"
      rescue Errno::EACCES => e
        raise ArgumentError, "could not open config file:\n#{e.inspect}"
      rescue YAML::SyntaxError => e
        raise "config file #{filename} is not proper yaml:\n#{e.inspect}"
      end
      return c.to_ruby
    end

    def reload!
      raise "You must parse command line options before reloading config" if @options.nil?
      @config = generate_nerve_config(@options)
    end
  end
end


