class Nerve::Reporter
  class Zookeeper < Base
    def self.new_from_service(service)
      self.new({
        'hosts' => service['zk_hosts'],
        'path' => service['zk_path'],
        'key' => "/#{service['instance_id']}_",
        'data' => {'host' => service['host'], 'port' => service['port'], 'name' => service['instance_id']},
      })
    end
  end
end

