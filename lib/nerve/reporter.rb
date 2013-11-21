require 'zk'

module Nerve
  class Reporter
    include Utils
    include Logging

    def initialize(opts)
      %w{hosts path key}.each do |required|
        raise ArgumentError, "you need to specify required argument #{required}" unless opts[required]
      end

      @path = opts['hosts'].shuffle.join(',') + opts['path']
      @data = parse_data(opts['data'] || '')
      @key = opts['key']
      @key.insert(0,'/') unless @key[0] == '/'
    end

    def start()
      log.info "nerve: waiting to connect to zookeeper at #{@path}"
      @zk = ZK.new(@path)

      log.info "nerve: successfully created zk connection to #{@path}"
    end

    def report_up(sequential=false)
      zk_save(sequential)
    end

    def report_down
      zk_delete
    end

    def update_data(new_data='', sequential=false)
      @data = parse_data(new_data)
      zk_save(sequential)
    end

    def ping?
      return @zk.ping?
    end

    private

    def zk_delete
      @zk.delete(@key, :ignore => :no_node)
    end

    def zk_save(sequential=false)
      log.debug "nerve: writing data #{@data.class} to zk at #{@key} with #{@data.inspect} and sequential flag is #{sequential}"
      begin
        @zk.set(@key,@data)
      rescue ZK::Exceptions::NoNode => e
        @zk.create(@key,:data => @data, :ephemeral => true, :sequential => sequential)
      end
    end

    def parse_data(data)
      return data if data.class == String
      return data.to_json
    end

  end
end
