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
      attr_reader :host, :port, :scheme, :ca_file, :ssl_version, :verify_mode, :api_key, :secret_key

      def initialize(options)
        if options.kind_of? String
          options = {CA_FILE_KEY => options}
        end
        options = symbolize_keys(options)

        load_url_option(options)
        load_ca_file_option(options)
        load_ssl_version_option(options)
        load_verify_option(options)
        load_api_keys_option(options)
      end

      private

      def load_url_option(options)
        url = URI::parse(options[URL_KEY] || DEFAULT_URL)
        @host = url.host or raise "Failed to obtain host name from given url: url = #{url.to_s}"
        @port = url.port or raise "Failed to obtain port number from given url: url = #{url.to_s}"
        @scheme = url.scheme or raise "Failed to obtain scheme from given url: url = #{url.to_s}"
        raise "Unsupported scheme '#{@scheme}'" unless AVAILABLE_SCHEMA.include? @scheme
      end

      def load_ca_file_option(options)
        @ca_file = options[CA_FILE_KEY] || DEFAULT_CA_FILE
        if @ca_file
          raise "ca_file option must be string value" unless @ca_file.is_a? String
          raise "ca_file option must be absolute path" unless @ca_file[0] == '/'
          raise "ca_file '#{@ca_file}' doesn't exist" unless File::exists? @ca_file
        end
      end

      def load_ssl_version_option(options)
        ssl_version = options[SSL_VERSION_KEY] || DEFAULT_SSL_VERSION
        raise "Unsupported SSL version '#{ssl_version}'" unless AVAILABLE_SSL_VERSIONS.has_key? ssl_version
        @ssl_version = AVAILABLE_SSL_VERSIONS[ssl_version]
      end

      def load_verify_option(options)
        skip_verify = options[SKIP_VERIFY_KEY] || DEFAULT_SKIP_VERIFY
        raise "skip_verify option must be boolean value" unless skip_verify.is_a?(TrueClass) || skip_verify.is_a?(FalseClass)
        @verify_mode = skip_verify ?  OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      end

      def load_api_keys_option(options)
        api_keys_file = options[API_KEYS_FILE_KEY] || DEFAULT_API_KEYS_FILES.find{|file|
          File::readable?(file) && File::file?(file)
        }
        raise "API keys file is not found" if api_keys_file.nil?

        api_keys = symbolize_keys(JSON::parse(File::read(api_keys_file)))
        @api_key = api_keys[API_KEYS_API_KEY_KEY]
        @secret_key = api_keys[API_KEYS_SECRET_KEY_KEY]
      rescue SystemCallError, RuntimeError => e
        STDERR.puts ""
        STDERR.puts "WARNING: Failed to read api_keys file. Check your api_keys file, or set api_keys manually by set_api_keys(API_KEY, SECRET_KEY): ERROR = #{e.to_s}"
        STDERR.puts ""
      end

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

      BAZIL_CONFIG_DIRS = [
        File::join(ENV['PWD'], '.bazil'),
        File::join(ENV['HOME'], '.bazil')
      ]

      API_KEYS_FILE_KEY = :api_keys
      DEFAULT_API_KEYS_FILES = BAZIL_CONFIG_DIRS.map{|dir| File::join(dir, 'api_keys') }
      API_KEYS_API_KEY_KEY = :api_key
      API_KEYS_SECRET_KEY_KEY = :secret_key
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
      set_api_keys(opt.api_key, opt.secret_key)
    end

    def_delegators :@http_cli, :read_timeout, :read_timeout=, :set_api_keys

    def models(options = {})
      queries = {}
      queries[:tag_id] = options[:tag_id].to_i if options.has_key? :tag_id
      queries[:page] = options[:page].to_i if options.has_key? :page
      queries[:per_page] = options[:per_page].to_i if options.has_key? :per_page

      res, body = @http_cli.get(gen_uri("models",queries))
      raise_error("Failed to get models", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)["models"].map{|model|
        model["config_ids"].map{|config_id|
          Model.new(self, model["id"].to_i, config_id.to_i)
        }
      }.flatten
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
      JSON.parse(res.body)
    end

    def create_config(model_id, config)
      data = config.to_json
      res, body = @http_cli.post(gen_uri("models/#{model_id}/configs"), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("Failed to create new configuration", res) unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      js = JSON.parse(res.body)
      Model.new(self, model_id, js['config_id'].to_i)
    end

    def delete_config(model_id, config_id)
      res, body = @http_cli.delete(gen_uri("models/#{model_id}/configs/#{config_id}"))
      raise_error("Failed to delete configuration", res) unless res.code =~ /2[0-9][0-9]/ # TODO: return detailed error information
      JSON.parse(res.body)
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

    def gen_uri(path, queries = {})
      if queries.empty?
        "/#{api_version}/#{path}"
      else
        "/#{api_version}/#{path}?#{queries.map{|k,v| "#{k}=#{v}"}.join('&')}"
      end
    end

    def raise_error(message, res)
      raise APIError.new(message, res.code, JSON.parse(res.body))
    end
  end # class Client
end # module Bazil
