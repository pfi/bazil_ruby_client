require 'forwardable'

require 'rubygems'
require 'json'
require 'net/http'
require 'net/https'
require 'bazil/model'
require 'bazil/rest'
require 'bazil/error'

module Bazil
  class Client
    extend Forwardable

    class Options
      attr_reader :host, :port, :scheme, :ca_file, :ssl_version, :verify_mode

      def initialize(options)
        if options.kind_of? String
          options = {CA_FILE_KEY => options}
        end
        options = symbolize_keys(options)

        url = URI::parse(options[URL_KEY] || DEFAULT_URL)
        @host = url.host or raise "Failed to obtain host name from given url: url = #{url.to_s}"
        @port = url.port or raise "Failed to obtain port number from given url: url = #{url.to_s}"
        @scheme = url.scheme or raise "Failed to obtain scheme from given url: url = #{url.to_s}"
        raise "Unsupported scheme '#{@scheme}'" unless AVAILABLE_SCHEMA.include? @scheme

        @ca_file = options[CA_FILE_KEY] || DEFAULT_CA_FILE
        if @ca_file
          raise "ca_file option must be string value" unless @ca_file.is_a? String
          raise "ca_file option must be absolute path" unless @ca_file[0] == '/'
          raise "ca_file '#{@ca_file}' doesn't exist" unless File::exists? @ca_file
        end

        ssl_version = options[SSL_VERSION_KEY] || DEFAULT_SSL_VERSION
        raise "Unsupported SSL version '#{ssl_version}'" unless AVAILABLE_SSL_VERSIONS.has_key? ssl_version
        @ssl_version = AVAILABLE_SSL_VERSIONS[ssl_version]

        skip_verify = options[SKIP_VERIFY_KEY] || DEFAULT_SKIP_VERIFY
        raise "skip_verify option must be boolean value" unless skip_verify.is_a?(TrueClass) || skip_verify.is_a?(FalseClass)
        @verify_mode = skip_verify ?  OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      end

      private

      def symbolize_keys(hash)
        {}.tap{|new_hash|
          hash.each{|k,v|
            new_hash[k.to_s.to_sym] = v
          }
        }
      end

      URL_KEY = :url
      DEFAULT_URL = 'https://asp-bazil.preferred.jp/'
      AVAILABLE_SCHEMA = ['http', 'https']

      CA_FILE_KEY = :ca_file
      DEFAULT_CA_FILE = nil

      SSL_VERSION_KEY = :ssl_version
      AVAILABLE_SSL_VERSIONS = {SSLv3: 'SSLv3', TLSv1: 'TLSv1'}
      DEFAULT_SSL_VERSION = :TLSv1

      SKIP_VERIFY_KEY = :skip_verify
      DEFAULT_SKIP_VERIFY = false
    end

    def set_ssl_options(http, options)
      http.use_ssl = options.scheme == 'https'
      http.ca_file = options.ca_file
      http.ssl_version = options.ssl_version
      http.verify_mode = options.verify_mode
    end

    def initialize(options={})
      opt = Options.new(options)
      http = Net::HTTP.new(opt.host, opt.port)
      set_ssl_options(http,opt)
      @http_cli = REST.new(http)
    end

    def_delegators :@http_cli, :read_timeout, :read_timeout=, :set_api_keys

    def status
      res = @http_cli.get(gen_uri('status'))
      raise_error("Failed to get status of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def config
      res = @http_cli.get(gen_uri('config'))
      raise_error("Failed to get config of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def update_config(config)
      data = config.to_json
      res = @http_cli.put(gen_uri('config'), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("Failed to update config of the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def errors
      res = @http_cli.get(gen_uri('errors'))
      raise_error("Failed to get information of errors from the server", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def clear_errors
      res = @http_cli.delete(gen_uri('errors'))
      raise_error("Failed to clear error information of the server", res) unless res.code =~ /2[0-9][0-9]/
      true
    end

    def models
      res, body = @http_cli.get(gen_uri('models'))
      raise_error("Failed to get models", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def create_model(config)
      data = config.to_json
      res, body = @http_cli.post(gen_uri('models'), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("Failed to create model", res) unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      js = JSON.parse(res.body)
      Model.new(self, js['model_id'].to_i, js['config_id'].to_i)
    end

    def delete_model(model_id)
      res, body = @http_cli.delete(gen_uri("models/#{model_id}"))
      raise_error("Failed to delete model", res) unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      model_id
    end

    def model(model_id, config_id)
      model = Model.new(self, model_id, config_id)
      model.status
      model
    end

    def http_client
      @http_cli
    end

    # TODO: make this changable
    def api_version
      'v2'
    end

    private

    def gen_uri(path)
      "/#{api_version}/#{path}"
    end

    def raise_error(message, res)
      raise APIError.new(message, res.code, JSON.parse(res.body))
    end
  end # class Client
end # module Bazil
