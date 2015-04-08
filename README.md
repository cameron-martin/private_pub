# Private Pub

**Warning: This gem is no way near ready, and development on it has ceased while I do university work. After university (summer 2015) I will probably continue with it, as there seems to be a bit of interest in it (three stars woot!)**

Private Pub is a Ruby gem for use with Rails to publish and subscribe to messages through [Faye](http://faye.jcoglan.com/). It allows you to easily provide real-time updates through an open socket without tying up a Rails process. All channels are private so users can only listen to events you subscribe them to.

Watch [RailsCasts Episode 316](http://railscasts.com/episodes/316-private-pub) for a demonstration of Private Pub.


## Setup

Add the gem to your Gemfile and run the `bundle` command to install it. You'll probably want to add "thin" to your Gemfile as well to serve Faye.

```ruby
gem "private_pub"
gem "thin"
```

Run the generator to create the initial files.

```
rails g private_pub:install
```

Next, start up Faye using the rackup file that was generated.

```
rackup private_pub.ru -s thin -E production
```

**In Rails 3.1** add the JavaScript file to your application.js file manifest.

```javascript
//= require private_pub
```

**In Rails 3.0** add the generated private_pub.js file to your layout.

```rhtml
<%= javascript_include_tag "private_pub" %>
```

It's not necessary to include faye.js since that will be handled automatically for you.


## Usage

Use the `sign_private_pub` helper method on any page to allow subscriptions and publications to specific channels.

```rhtml
<%= sign_private_pub do |p|
  p.subscribe '/messages/new', '/messages/spam'
  p.publish '/messages/create'
end %>
```

You can publish json by passing a hash to `PrivatePub.publish_to`. This can be done anywhere (such as the controller).

```ruby
PrivatePub.publish_to "/messages/new", :chat_message => "Hello, world!"
```

And then handle this through JavaScript on the client side.

```javascript
private_pub.subscribe("/messages/new", function(data, channel) {
  $("#chat").append(data.chat_message);
});
```

`private_pub.subscribe` returns a promise that resolves to the function to cancel the subscription. If you can think of a more sensible api, open an issue.

```javascript
private_pub.subscribe("/messages/new", function(data, channel) { }).then(function(cancel) {
  setTimeout(cancel, 1000); // Cancel subscription 1 second
});
```

You can also call cancel directly on the promise returned by `private_pub.subscribe`.

```javascript
var subscription = private_pub.subscribe("/messages/new", function(data, channel) { });
subscription.cancel().then(function() {
  console.log('Subscription cancelled.');
});
```


## Configuration

The configuration is set via environment variables:

* `PRIVATE_PUB_SERVER`: The URL to use for the Faye server such as `http://localhost:9292/faye`.
* `PRIVATE_PUB_SECRET_TOKEN`: A secret hash to secure the server. Can be any string.
* `PRIVATE_PUB_EXPIRES`: The length of time in seconds before a subscription signature expires. If this is not set there is no expiration. Note: if Faye is on a separate server from the Rails app, the system clocks must be in sync for the expiration to work properly.


## How It Works

The `sign_private_pub` helper will output the following script which authorizes the user to publish or subscribe to a specific channel.

```html
<script type="text/javascript">
  var private_pub = PrivatePub("http://localhost:9292/faye");
  private_pub.sign({
    channel: "/messages/new",
    expires_at: 1302306682972,
    signature: "dc1c71d3e959ebb6f49aa6af0c86304a0740088d",
  });
</script>
```

The signature and timestamp are checked on the Faye server to ensure users are only able to access channels you subscribe them to.
The signature will automatically expire after the time specified in the configuration.

The `publish_to` method will send a post request to the Faye server (using `Net::HTTP`) instructing it to send the given data back to the browser.


## Serving Faye over HTTPS (with Thin)

To server Faye over HTTPS you could create a thin configuration file `config/private_pub_thin.yml` similar to the following:

```yaml
---
port: 4443
ssl: true
ssl_key_file: /path/to/server.pem
ssl_cert_file: /path/to/certificate_chain.pem
environment: production
rackup: private_pub.ru
```

The `certificate_chain.pem` file should contain your signed certificate, followed by intermediate certificates (if any) and the root certificate of the CA that signed the key.

Next reconfigure the URL in `config/private_pub.yml` to look like `https://your.hostname.com:4443/faye`

Finally start up Thin from the project root.

```
thin -C config/private_pub_thin.yml start
```


##  Project Status

This is a fork of the original private_pub by Ryan Baits

### Changes from the original

* Changed configuration from using yaml file to environment variables.
  This stops you committing your secret token to your git repository.
* Changed to using HMAC for generating the signature, to prevent extension attacks.
* Added token and signature methods for both subscribing and publishing
* It no longer supports sending JS directly to be evalled on the client. Only communicating via JSON is supported.

## Development & Feedback

Questions or comments? Please use the [issue tracker](https://github.com/ryanb/private_pub/issues). Tests can be run with `bundle` and `rake` commands.
