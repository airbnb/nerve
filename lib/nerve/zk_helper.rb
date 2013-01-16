module Nerve
  class ZKHelper
    def initialize(path)
      @zk = ZK.new(path)
    end

    def create_service_node  
      # create ephemeral node in zookeeper under <root>/services/<service name>/<instance_id>
      # write json hash {ip:ip, host:host, port:port} into ephemeral node
    end

    def delete(path)
      @zk.delete(path, :ignore => :no_node)
    end

    def create_ephemeral_node(path, data="")
      @zk.delete(path, :ignore => :no_node)
      create_path(File.dirname(path))
      @zk.create(path, :data => data.to_json, :mode => :ephemeral)
    end

    def ensure_ephemeral_node(path,data='')
      @zk.create(path, :data => data.to_json, :mode => :ephemeral, :ignore => :node_exists)
    end

    def ping?
      return @zk.ping?
    end

    def update(path,data='')
      @zk.set(path,data)
    end

    # recursively creates a zk path
    def create_path(path)
      return if @zk.exists?(path)
      create_path File.dirname(path)
      @zk.create(path)
    end

  end
end
