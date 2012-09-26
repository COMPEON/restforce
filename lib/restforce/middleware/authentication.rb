module Restforce
  # Faraday middleware that allows for on the fly authentication of requests.
  # When a request fails (ie. A status of 401 is returned). The middleware
  # will attempt to either reauthenticate (username and password) or refresh
  # the oauth access token (if a refresh token is present).
  class Middleware::Authentication < Restforce::Middleware
    autoload :Password, 'restforce/middleware/authentication/password'
    autoload :Token,    'restforce/middleware/authentication/token'

    # Rescue from 401's, authenticate then raise the error again so the client
    # can reissue the request.
    def call(env)
      @app.call(env)
    rescue Restforce::UnauthorizedError
      authenticate!
      raise
    end

    # Internal: Performs the authentication and returns the response body.
    def authenticate!
      response = connection.post '/services/oauth2/token' do |req|
        req.body = URI.encode_www_form params
      end
      raise Restforce::AuthenticationError, error_message(response) if response.status != 200
      @options[:instance_url] = response.body['instance_url']
      @options[:oauth_token]  = response.body['access_token']
      response.body
    end

    # Internal: The params to post to the OAuth service.
    def params
      raise 'not implemented'
    end

    # Internal: Faraday connection to use when sending an authentication request.
    def connection
      @connection ||= Faraday.new(:url => "https://#{@options[:host]}") do |builder|
        builder.use Restforce::Middleware::Mashify, nil, @options
        builder.response :json
        builder.use Restforce::Middleware::Logger, Restforce.configuration.logger, @options if Restforce.log?
        builder.adapter Faraday.default_adapter
      end
    end

    # Internal: The parsed error response.
    def error_message(response)
      "#{response.body['error']}: #{response.body['error_description']}"
    end
  end
end
