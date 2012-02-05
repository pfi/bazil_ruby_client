require 'rubygems'
require 'json'

module Bazil
  class Model
    attr_reader :application, :name

    def initialize(http_cli, app, name)
      @http_cli = http_cli
      @application = app
      @name = name

      status
    end

    def status
      res = @http_cli.get(gen_uri('status'))
      raise "Failed to get status of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    # TODO: config
    # TODO: retrain
    # TODO: label APIs

    def train(label, data)
      data = %({"label": "#{label}", "data": #{data.to_json}})
      body = post('training_data', data, "Failed to post training data")
      JSON.parse(body)
    end

    def training_data(id)
      res = @http_cli.get(gen_uri("training_data/#{id}"))
      raise "Failed to get training data of the model: id = #{id}, #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def list_training_data(condition)
      # TODO: validate parameter
      condition[:page] ||= 1
      condition[:pagesize] ||= 10
      res = @http_cli.get(gen_uri("training_data?page=#{condition[:page]}&pagesize=#{condition[:pagesize]}"))
      raise "Failed to get training data of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      JSON.parse(res.body)
    end

    def clear_training_data
      res = @http_cli.delete(gen_uri("training_data"))
      raise "Failed to clear training_data of the model: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/
      true
    end

    def put_training_data(data)
      data = %({"data": #{data.to_json}})
      body = post('training_data', data, "Failed to post training data")
      JSON.parse(body)
    end

    def classify(data)
      data = %({"data": #{data.to_json}})
      res = JSON.parse(post('classify', data, "Failed to post data for classification"))
      return res['max_label'], res
    end

    private
    def post(path, data, error_message)
      res = @http_cli.post(gen_uri(path), data, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => data.length.to_s})
      raise "#{error_message}: #{error_suffix}" unless res.code =~ /2[0-9][0-9]/ # TODO: enhance error information
      res.body
    end

    def gen_uri(path = nil)
      if path
        "/apps/#{@application.name}/models/#{@name}/#{path}"
      else
        "/apps/#{@application.name}/models/#{@name}"
      end
    end

    def error_suffix
      "application = #{@application.name}, model = #{@name}"
    end
  end # module Model
end # module Bazil
