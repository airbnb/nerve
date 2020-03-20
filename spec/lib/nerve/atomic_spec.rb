require 'spec_helper'
require 'nerve/atomic'

describe Nerve::AtomicValue do
  let(:initial_value) { 'mock-value' }
  let(:internal_mu) { subject.instance_variable_get(:@mu) }

  subject { Nerve::AtomicValue.new(initial_value) }

  describe '#initialize' do
    it 'creates successfully' do
      expect { subject }.not_to raise_error
    end

    it 'sets the initial value' do
      expect(subject.get).to eq(initial_value)
    end

    context 'without a provided value' do
      it 'defaults to nil' do
        atom = Nerve::AtomicValue.new
        expect(atom.get).to eq(nil)
      end
    end
  end

  describe '#get' do
    let(:value) { 'new-value' }

    before :each do
      subject.instance_variable_set(:@value, value)
    end

    it 'returns the internal value' do
      expect(subject.get).to eq(value)
    end

    it 'holds a lock' do
      expect(internal_mu).to receive(:synchronize).exactly(:once)
      subject.get
    end

    it 'releases lock after call' do
      expect(internal_mu.locked?).to eq(false)
      subject.get
    end

    context 'after a set' do
      it 'returns the new value' do
        subject.set(value)
        expect(subject.get).to eq(value)
      end
    end
  end

  describe '#set' do
    let(:value) { 'new-value' }

    it 'sets the internal value' do
      expect { subject.set(value) }
        .to change { subject.instance_variable_get(:@value) }
        .from(initial_value).to(value)
    end

    it 'holds a lock' do
      expect(internal_mu).to receive(:synchronize).exactly(:once)
      subject.set(value)
    end

    it 'releases lock after call' do
      expect(internal_mu.locked?).to eq(false)
      subject.set(value)
    end
  end
end
