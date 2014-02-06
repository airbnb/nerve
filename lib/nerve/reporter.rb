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
      @key.insert(-1, '_') unless @key[-1] == '_'
      @full_key = nil
    end

    def start()
      log.info "nerve: waiting to connect to zookeeper at #{@path}"
      @zk = ZK.new(@path)

      log.info "nerve: successfully created zk connection to #{@path}"
    end

    def report_up()
      zk_save
    end

    def report_down
      zk_delete
    end

    def update_data(new_data='')
      @data = parse_data(new_data)
      zk_save
    end

    def ping?
      return @zk.ping?
    end

    private

    def zk_delete
      if @full_key
        @zk.delete(@full_key, :ignore => :no_node)
        @full_key = nil
      end
    end

    def zk_create
      @full_key = @zk.create(@key, :data => @data, :mode => :ephemeral_sequential)
    end

    def zk_save
      return zk_create unless @full_key

      begin
        @zk.set(@full_key, @data)
      rescue ZK::Exceptions::NoNode
        zk_create
      end
    end

    def parse_data(data)
      return data if data.class == String
      return data.to_json
    end

  end
end
