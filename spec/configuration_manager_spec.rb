require 'spec_helper'
require 'nerve/configuration_manager'

describe Nerve::ConfigurationManager do
  describe 'normal run' do
    let(:config_manager) { Nerve::ConfigurationManager.new() }
    let(:nerve_config) { "#{File.dirname(__FILE__)}/../example/nerve.conf.json" }
    let(:nerve_instance_id) { "testid" }

    it 'can parse options' do
      allow(ENV).to receive(:[]).with("NERVE_CONFIG").and_return(nerve_config)
      allow(ENV).to receive(:[]).with("NERVE_INSTANCE_ID").and_return(nerve_instance_id)
      allow(ENV).to receive(:[]).with("NERVE_CHECK_CONFIG").and_return(false)

      expect{config_manager.reload!}.to raise_error(RuntimeError)
      expect(config_manager.parse_options!).to eql({
        :config => "/Users/jlynch/pg/nerve/spec/../example/nerve.conf.json",
        :instance_id => "testid",
        :check_config => false
      })
      expect(config_manager.reload!).to_not raise_error(RuntimeError)
      raise
    end
  end
end
