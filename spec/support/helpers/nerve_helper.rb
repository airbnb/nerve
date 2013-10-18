module NerveHelper

  def nerve
    @nerve ||= DSL.new
  end

  class DSL
    extend Forwardable

    attr_reader :process

    def_delegators :process,
      :machine_check_root,
      :machine_check_path,
      :machine_check_node,
      :service_check_root,
      :service_check_path

    def configure(config={})
      @process = Nerve::NerveProcess.new(config.merge(zk_config))
    end

    def initialize_zk
      ZooKeeperHelper.zk.tap do |zk|
        zk.create(@process.machine_check_root, '')
        zk.create(@process.service_check_root, '')
      end
    end

    def start
      @process.start
    end

    def stop(options={})
      @process.stop(options={})
      @process = nil
    end

    def restart(options={})
      @process.restart(options)
    end

    def wait_for_up(timeout=5)
      until_timeout(timeout, "Nerve never came up") do
        raise unless @process.up?
      end
    rescue Timeout::Error => e
      @process.wait
      puts "\nNERVE ERROR:"
      puts @process.stderr
      raise e
    end

    def zk_config
      {:zk_servers => ZooKeeperHelper.sockets}
    end

  end

end
