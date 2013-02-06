require 'rubygems'
require 'json'
require 'bazil/error'

module Bazil
  class Model
    attr_reader :model_id, :config_id

    def initialize(client, model_id, config_id)
      @client = client
      @http_cli = client.http_client
      @model_id = model_id
      @config_id = config_id
    end

    def status
      res = @http_cli.get(gen_uri(target_path(@config_id, "status")))
      raise_error("Failed to get status of the model: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def model_config
      res = @http_cli.get(gen_uri())
      raise_error("Failed to get model config: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def update_model_config(conf)
      res = @http_cli.put(gen_uri(), conf.to_json, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => conf.to_json.length.to_s})
      JSON.parse(res.body)
    end

    def config
      res = @http_cli.get(gen_uri("configs/#{@config_id}"))
      raise_error("Failed to get config of the model: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def update_config(config)
      res = send(:put, "configs/#{@config_id}", config.to_json, "Failed to updated config")
      {}
    end

    def train(train_data)
      raise ArgumentError, 'Annotation must be not nil' unless train_data.has_key? :annotation
      raise ArgumentError, 'Data must be not nil' unless train_data.has_key? :data

      body = post("training_data", train_data.to_json, "Failed to post training data")
      JSON.parse(body)
    end

    def retrain(option = {})
      body = post(target_path(@config_id, 'retrain'), option.to_json, "Failed to retrain the model")
      JSON.parse(body)
    end

    def trace(method, data, config = nil)
      new_data = {}
      new_data['method'] = method if method
      new_data['data'] = data if data
      new_data['config'] = config if config
      body = post(target_path(@config_id, "trace"), new_data.to_json, "Failed to execute trace")
      JSON.parse(body)
    end

    def evaluate(method, config = nil)
      new_data = {}
      new_data['method'] = method if method
      new_data['config'] = config if config
      body = post(target_path(@config_id, "evaluate"), new_data.to_json, "Failed to execute evaluate")
      JSON.parse(body)
    end

    def labels
      res = @http_cli.get(gen_uri(target_path(@config_id, "labels")))
      raise_error("Failed to get labels the model has: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)['labels']
    end

    def training_data(id)
      raise ArgumentError, 'Id must be Integer' unless id.kind_of? Integer
      res = @http_cli.get(gen_uri("training_data/#{id}"))
      raise_error("Failed to get training data of the model: id = #{id}, #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def list_training_data(condition = {})
      condition = condition.dup
      condition[:page] ||= 1
      condition[:per_page] ||= 10

      res = @http_cli.get(gen_uri("training_data?page=#{condition[:page]}&per_page=#{condition[:per_page]}"))
      raise_error("Failed to query training data of the model", res) unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def clear_training_data
      res = @http_cli.delete(gen_uri("training_data"))
      raise_error("Failed to clear training_data of the model: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      {}
    end

    def put_training_data(new_data = {})
      raise ArgumentError, 'Data must be not nil' unless new_data.has_key? :data
      body = post('training_data', new_data.to_json, "Failed to post training data")
      JSON.parse(body)
    end

    def update_training_data(id, new_data = {})
      raise ArgumentError, 'Id must be Integer' unless id.kind_of? Integer
      raise ArgumentError, 'Data must be not nil' unless new_data.has_key? :data
      send(:put, "training_data/#{id}", new_data.to_json, "Failed to update training data")
      {}
    end

    def delete_training_data(id)
      raise ArgumentError, 'Id must be Integer' unless id.kind_of? Integer
      res = @http_cli.delete(gen_uri("training_data/#{id}"))
      raise_error("Failed to delete a training data: id = #{id}, #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/
      {}
    end

    def query(data)
      data = {'data' => data}.to_json
      res = post(target_path(@config_id, 'query'), data, "Failed to post data for query")
      JSON.parse(res)
    end

    private

    def post(path, data, error_message)
      send(:post, path, data, error_message)
    end

    def send(method, path, data, error_message)
      res = @http_cli.method(method).call(gen_uri(path), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise_error("#{error_message}: #{error_suffix}", res) unless res.code =~ /2[0-9][0-9]/ # TODO: enhance error information
      res.body
    end

    def target_path(id, path)
      "configs/#{id}/#{path}"
    end

    def gen_uri(path = nil)
      if path
        "/#{@client.api_version}/models/#{@model_id}/#{path}"
      else
        "/#{@client.api_version}/models/#{@model_id}"
      end
    end

    def error_suffix
      "model = #{@model_id}"
    end

    def raise_error(message, res)
      raise APIError.new(message, res.code, JSON.parse(res.body))
    end
  end # module Model
end # module Bazil
