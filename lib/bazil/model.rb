require 'rubygems'
require 'json'

module Bazil
  class Model
    attr_reader :application, :name

    def initialize(client, app, name, default_config_id = nil)
      @client = client
      @http_cli = client.http_client
      @application = app
      @name = name

      # Model#initialize does not have config_id
      if default_config_id
        set_default_config_id(default_config_id)
        status
      end
    end

    def set_default_config_id(id)
      @default_config_id = id
    end

    def get_default_config_id
      raise 'default_config_id is not set' if @default_config_id.nil?
      @default_config_id
    end

    def status(config_id = get_default_config_id)
      res = @http_cli.get(gen_uri(target_path(config_id, "status")))
      raise "Failed to get status of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def config(config_id = get_default_config_id)
      res = @http_cli.get(gen_uri("configs/#{config_id}"))
      raise "Failed to get config of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def config_ids
      res = @http_cli.get(gen_uri('configs'))
      raise "Failed to get config of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)['config_ids']
    end

    def update_config(conf, config_id = get_default_config_id)
      res = send(:put, "configs/#{config_id}", conf.to_json, "Failed to updated config")
      true
    end

    # TODO: label APIs

    def train(label, data, config_id = get_default_config_id)
      data = %({"label": "#{label}", "data": #{data.to_json}, "config_id": "#{config_id}"})
      body = post("training_data", data, "Failed to post training data")
      JSON.parse(body)
    end

    def retrain(option = {}, config_id = get_default_config_id)
      body = post(target_path(config_id, 'retrain'), option.to_json, "Failed to retrain the model")
      JSON.parse(body)
    end

    def labels(config_id = get_default_config_id)
      res = @http_cli.get(gen_uri(target_path(config_id, "labels")))
      raise "Failed to get labels the model has: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)['labels']
    end

    def training_data(id)
      res = @http_cli.get(gen_uri("training_data/#{id}"))
      raise "Failed to get training data of the model: id = #{id}, #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def list_training_data(condition)
      # TODO: validate parameter
      condition[:page] ||= 1
      condition[:page_size] ||= 10
      condition[:query] ||= { :version => '1' }
      condition[:query][:version] = '1' unless condition[:query][:version]

      res = post("training_data/query?page=#{condition[:page]}&page_size=#{condition[:page_size]}",
                 condition[:query].to_json, "Failed to query training data of the model")
      JSON.parse(res)
    end

    def clear_training_data
      res = @http_cli.delete(gen_uri("training_data"))
      raise "Failed to clear training_data of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      true
    end

    def put_training_data(data, config_id = get_default_config_id)
      data = %({"data": #{data.to_json}, "config_id": "#{config_id}"})
      body = post('training_data', data, "Failed to post training data")
      JSON.parse(body)
    end

    def update_training_data(id, label, data, config_id = get_default_config_id)
      # TODO: type check of id
      new_data = {}
      new_data['label'] = label if label
      new_data['data'] = data if data
      new_data['config_id'] = config_id
      new_data = new_data.to_json
      send(:put, "training_data/#{id}", new_data, "Failed to update training data")
      true
    end

    def delete_training_data(id)
      # TODO: type check of id
      res = @http_cli.delete(gen_uri("training_data/#{id}"))
      raise "Failed to delete a training data: id = #{id}, #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      true
    end

    def query(data, config_id = get_default_config_id)
      data = {'data' => data}.to_json
      res = JSON.parse(post(target_path(config_id, 'query'), data, "Failed to post data for query"))
      return res['max_label'], res
    end

    private

    def post(path, data, error_message)
      send(:post, path, data, error_message)
    end

    def send(method, path, data, error_message)
      res = @http_cli.method(method).call(gen_uri(path), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise "#{error_message}: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/ # TODO: enhance error information
      res.body
    end

    def target_path(id, path)
      "configs/#{id}/#{path}"
    end

    def gen_uri(path = nil)
      if path
        "/#{@client.api_version}/apps/#{@application.name}/models/#{@name}/#{path}"
      else
        "/#{@client.api_version}/apps/#{@application.name}/models/#{@name}"
      end
    end

    def error_suffix
      "application = #{@application.name}, model = #{@name}"
    end
  end # module Model
end # module Bazil
