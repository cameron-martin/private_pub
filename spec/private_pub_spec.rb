require 'spec_helper'

describe PrivatePub do

  let(:token) { 'token' }

  before(:each) do
    stub_config(secret_token: token)
  end

  it 'defaults server to nil' do
    expect(PrivatePub.config[:server]).to be_nil
  end

  it 'defaults signature_expiration to nil' do
    expect(PrivatePub.config[:signature_expiration]).to be_nil
  end

  it 'formats a message hash given a channel and a hash' do
    expect(PrivatePub.message('chan', foo: 'bar')).to eq(
      ext: { private_pub_token: token },
      channel: 'chan',
      data: { foo: 'bar' }
    )
  end

  it 'publish message as json to server using Net::HTTP' do
    stub_config(server: 'http://localhost')
    message = 'foo'
    form = double(:post).as_null_object
    http = double(:http).as_null_object

    expect(Net::HTTP::Post).to receive(:new).with('/').and_return(form)
    expect(form).to receive(:set_form_data).with(message: 'foo'.to_json)

    expect(Net::HTTP).to receive(:new).with('localhost', 80).and_return(http)
    expect(http).to receive(:start).and_yield(http)
    expect(http).to receive(:request).with(form).and_return(:result)

    expect(PrivatePub.publish_message(message)).to eq(:result)
  end

  it 'it should use HTTPS if the server URL says so' do
    stub_config(server: 'https://localhost')
    http = double(:http).as_null_object

    expect(Net::HTTP).to receive(:new).and_return(http)
    expect(http).to receive(:use_ssl=).with(true)

    PrivatePub.publish_message('foo')
  end

  it 'it should not use HTTPS if the server URL says not to' do
    stub_config(server: 'http://localhost')
    http = double(:http).as_null_object

    expect(Net::HTTP).to receive(:new).and_return(http)
    expect(http).to receive(:use_ssl=).with(false)

    PrivatePub.publish_message('foo')
  end

  it 'raises an exception if no server is specified when calling publish_message' do
    expect {
      PrivatePub.publish_message('foo')
    }.to raise_error(PrivatePub::Error)
  end

  it 'publish_to passes message to publish_message call' do
    expect(PrivatePub).to receive(:message).with('chan', 'foo').and_return('message')
    expect(PrivatePub).to receive(:publish_message).with('message').and_return(:result)
    expect(PrivatePub.publish_to('chan', 'foo')).to eq(:result)
  end

  it 'has a Faye rack app instance' do
    expect(PrivatePub.faye_app).to be_kind_of(Faye::RackAdapter)
  end

  describe '.js_timestamp' do
    it 'calculates integer js time' do
      time = Time.now

      expect(PrivatePub.js_timestamp(time)).to eq((time.to_f * 1000).round)
    end

    it 'defaults to current time in milliseconds' do
      time = Time.now
      allow(Time).to receive(:now).and_return(time)

      expect(PrivatePub.js_timestamp).to eq(PrivatePub.js_timestamp(time))
    end
  end

  describe '.generate_signature' do
    it 'generates an hmac of channel, timestamp using secret token' do
      signature = PrivatePub.generate_signature('channel', 123, :subscribe)
      digest = OpenSSL::Digest.new('sha1')
      expected_signature = OpenSSL::HMAC.hexdigest(digest, token, 'channel123subscribe')

      expect(signature).to eq(expected_signature)
    end
  end

end
