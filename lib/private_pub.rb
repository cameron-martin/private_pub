require 'openssl'
require 'json'
require 'procto'

require 'net/http'
require 'net/https'

require 'private_pub/faye_extension'
require 'private_pub/message'
require 'private_pub/message_factory'

require 'private_pub/signature_message'
require 'private_pub/signature_validator'
require 'private_pub/signature'

require 'private_pub/token_validator'
require 'private_pub/token_message'
require 'private_pub/engine' if defined? Rails

module PrivatePub
  class Error < StandardError; end

  class << self
    attr_reader :config

    def reset_config
      @config = {}
    end

    # Publish the given data to a specific channel. This ends up sending
    # a Net::HTTP POST request to the Faye server.
    def publish_to(channel, data)
      publish_message(message(channel, data))
    end

    # Sends the given message hash to the Faye server using Net::HTTP.
    def publish_message(message)
      raise Error, 'No server specified, ensure configuration was loaded properly.' unless config[:server]
      url = URI.parse(config[:server])

      form = Net::HTTP::Post.new(url.path.empty? ? '/' : url.path)
      form.set_form_data(:message => message.to_json)

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == 'https'
      http.start {|h| h.request(form)}
    end

    # Returns a message hash for sending to Faye
    def message(channel, data)
      message = {channel: channel, data: { channel: channel }, ext: { private_pub_token: config[:secret_token] } }
      if data.kind_of? String
        message[:data][:eval] = data
      else
        message[:data][:data] = data
      end
      message
    end

    def generate_signature(channel, timestamp, action)
      digest = OpenSSL::Digest.new('sha1')
      OpenSSL::HMAC.hexdigest(digest, config[:secret_token], [channel, timestamp, action].join)
    end

    # Determine if the signature has expired given a timestamp.
    def signature_expired?(timestamp)
      !!(config[:signature_expiration] && timestamp < (js_timestamp - config[:signature_expiration]*1000))
    end

    def js_timestamp(time=Time.now)
      (time.to_f * 1000).round
    end

    # Returns the Faye Rack application.
    # Any options given are passed to the Faye::RackAdapter.
    def faye_app(options = {})
      options = {:mount => '/faye', :timeout => 25, :extensions => [FayeExtension.new]}.merge(options)
      Faye::RackAdapter.new(options)
    end
  end

  reset_config
end
