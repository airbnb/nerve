module NerveHelper

  def nerve
    @nerve ||= DSL.new
  end

  class DSL
    attr_reader :process

    def initialize_zk
      ZooKeeperHelper.zk.tap do |zk|
        zk.create('/services', '')
        zk.create('/machines', '')
      end
    end

    def start(config={})
      @process = Nerve::NerveProcess.new(config.merge(zk_config))
      @process.start
    end

    def stop
      @process.stop
      @process = nil
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

    def machine_check_path
      @process.machine_check_path
    end

  end

end