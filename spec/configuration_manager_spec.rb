require 'spec_helper'
require 'nerve/configuration_manager'

describe Nerve::ConfigurationManager do
  describe 'normal run' do
    let(:config_manager) { Nerve::ConfigurationManager.new() }
    let(:nerve_config) { "#{File.dirname(__FILE__)}/../example/nerve.conf.json" }
    let(:nerve_instance_id) { "testid" }

    it 'parses options' do
      allow(config_manager).to receive(:parse_options_from_argv!) { {
        :config => "/Users/jlynch/pg/nerve/spec/../example/nerve.conf.json",
        :instance_id => "testid",
        :check_config => false
      } }

      expect{config_manager.reload!}.to raise_error(RuntimeError)
      expect(config_manager.parse_options!).to eql({
        :config => "/Users/jlynch/pg/nerve/spec/../example/nerve.conf.json",
        :instance_id => "testid",
        :check_config => false
      })
      expect{config_manager.reload!}.not_to raise_error
      expect(config_manager.config.keys()).to include('instance_id', 'services')
      expect(config_manager.config['services'].keys()).to contain_exactly(
        'your_http_service', 'your_tcp_service', 'rabbitmq_service',
        'etcd_service1', 'zookeeper_service1'
      )
    end
  end
end
