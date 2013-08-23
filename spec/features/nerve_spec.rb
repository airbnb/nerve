require 'spec_helper'

describe Nerve do

  # Ensure that sessions expire rather quickly.
  let(:zookeeper_config) { { :minSessionTimeout => 2000, :maxSessionTimeout => 2000 } }
  let(:zookeeper_options) { { :zoocfg => zookeeper_config } }

  let(:nerve_config) { {} }

  before do
    zookeeper.start(zookeeper_options)
    zookeeper.wait_for_up

    nerve.configure(nerve_config)
    nerve.initialize_zk
  end

  it "should announce the machine" do

    nerve.start
    nerve.wait_for_up

    until_timeout(10) do
      zookeeper.children(nerve.machine_check_path).should_not be_empty
    end
  end

  context "when restarted" do

    context "and reconnects before the session expires" do

      it "should announce the machine" do
        nerve.start
        nerve.wait_for_up

        until_timeout(10) do
          zookeeper.children(nerve.machine_check_path).should_not be_empty
        end

        nerve.restart(:signal => :KILL)
        nerve.wait_for_up

        # Wait for the ephemeral node to possibly disappear.
        sleep 5

        until_timeout(10) do
          zookeeper.children(nerve.machine_check_path).should_not be_empty
        end
      end

    end

    context "and reconnects after the session expires" do

      it "should announce the machine" do
        # don't start nerve until after the session timeout
        # ensure ephemeral node exists before and after the session timeout
      end

    end

  end

  context "when a server in the ensemble is restarted" do

    it "should not go down" do
    end

    it "should announce the machine without interruption" do
    end

  end

  context "when the server it is connected to is restarted" do

    it "should not go down" do
    end

    it "should reconnect to a remaining server in the ensemble" do
    end

    context "and reconnects before the session expires" do

      it "should announce the machine without interruption" do
      end

    end

    context "and reconnects after the session expires" do

      it "should announce the machine" do
      end

    end

  end

  context "when the ensemble loses quorum" do

    it "should not go down" do
    end

    it "should announce the machine without interruption" do
    end

  end

  context "when the server it is connected to fails and the ensemble loses quorum" do

    it "should not go down" do
    end

    it "should reconnect to a remaining server in the ensemble" do
    end

    context "and quorum is re-established before the session expires" do

      it "should announce the machine without interruption" do # not sure if this is possible, might be interrupted
      end

    end

    context "and quorum is re-established after the session expires" do

      it "should announce the machine" do
      end

    end

  end

  context "when the ensemble is unreachbale" do

    it "should not go down" do
    end

    it "should reconnect" do
    end

    context "and becomes reachable again before the session expires" do

      it "should announce the machine without interruption" do
      end

    end

    context "and becomes reachable again after the session expires" do

      it "should announce the machine" do
      end

    end

  end

  context "when the ensemble fails completely" do

    it "should not go down" do
    end

    it "should reconnect" do
    end

    it "should announce the machine" do
    end

  end

end
