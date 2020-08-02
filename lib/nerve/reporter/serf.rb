require 'nerve/reporter/base'

class Nerve::Reporter
  class Serf < Base
    def initialize(service)

      # Set default parameters - the defaults are sane so nothing needed.
      @config_dir = service['serf_config_dir'] || '/etc/serf'
      @reload_command = service['serf_reload_command'] || '/usr/bin/killall -HUP serf'
      @name       = service['name']
      # please note that because of
      # https://github.com/airbnb/smartstack-cookbook/blob/master/recipes/nerve.rb#L71
      # the name won't just be the name you gave but name_port. this allows a same
      # service to be on multiple ports of a same machine.

      @data = parse_data(get_service_data(service))
      @config_file = File.join(@config_dir,"zzz_nerve_#{@name}.json")
      File.unlink @config_file if File.exists? @config_file
    end

    def start()
      log.info "nerve: started to maintain the tag #{@name} with Serf"
    end

    def report_up()
      update_data(false)
    end

    def report_down
      File.unlink(@config_file)
      reload_serf
    end

    def update_data(new_data='')
      @data = new_data if new_data
      data = JSON.parse(@data)
      tag = "#{data['host']}:#{data['port']}"
      File.write(@config_file, JSON.generate({tags:{"smart:#{@name}" =>tag}}))
      reload_serf
    end

    def reload_serf()
      system(@reload_command)
    end

    def ping?
      # for now return true.
      return true
    end
  end
end
