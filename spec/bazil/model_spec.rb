require 'bazil'
require 'net/http'
require 'rspec'
require 'rspec/mocks'

class FakeResponse
  attr_reader :code, :message, :body
  def initialize(code,message,body)
    @code = code
    @message = message
    @body = body
  end
end

class FakeClient
  attr_accessor :http_client
  def initialize
    @http_client = Object.new
  end
  def api_version
    'v2'
  end
end

describe Bazil::Client  do
  let(:client) { FakeClient.new }
  let(:model_id) { 42 }
  let(:config_id) { 184 }

  def gen_model_path(path = "")
    "/#{client.api_version}/models/#{model_id}#{path}"
  end

  def gen_model_config_path(path = "")
    "/#{client.api_version}/models/#{model_id}/configs/#{config_id}#{path}"
  end

  def header_for_json(js)
    {
      "Content-Type" => "application/json; charset=UTF-8",
      "Content-Length" => js.to_json.length.to_s
    }
  end

  let(:model) {
    Bazil::Model.new(client, model_id, config_id)
  }

  describe "model" do
    it "model_config send GET /models/:model_id" do
      result = {}
      client.http_client.should_receive(:get).with(gen_model_path("")).and_return(FakeResponse.new("200", "OK", result.to_json))
      res = model.model_config
      expect(res).to eq(result)
    end

    it "update_model_config send PUT /models/:model_id" do
      arg = {id: model_id, name: 'test'}
      result = {}
      client.http_client.should_receive(:put).with(gen_model_path(""), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      res = model.update_model_config(arg)
      expect(res).to eq(result)
    end

    it "config send GET /models/:model_id/configs/:config_id" do
      result = {}
      client.http_client.should_receive(:get).with(gen_model_config_path("")).and_return(FakeResponse.new("200", "OK", result.to_json))
      res = model.config
      expect(res).to eq(result)
    end

    it "update_config send PUT /models/:model_id/configs/:config_id" do
      arg = {methd: 'arow', id: config_id, model_id: model_id}
      result = {}
      client.http_client.should_receive(:put).with(gen_model_config_path(""), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      res = model.update_config(arg)
      expect(res).to eq(result)
    end

    it "status request GET /models/:model_id/configs/:config_id/status" do
      result = { "num_features" => 0, "num_train_queries" => 0, "num_labels" => 0, "num_queries" => 0, }
      client.http_client.should_receive(:get).with(gen_model_config_path("/status")).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.status).to eq(result)
    end

    it "retrain with empty option request POST /models/:model_id/configs/:config_id/retrain" do
      arg = {}
      result = { "total" => 1000, "elapsed_time" => 0.5 }
      client.http_client.should_receive(:post).with(gen_model_config_path("/retrain"), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.retrain).to eq(result)
    end

    it "retrain with option request POST /models/:model_id/configs/:config_id/retrain" do
      arg = {times: 10}
      result = { "total" => 1000, "elapsed_time" => 0.5 }
      client.http_client.should_receive(:post).with(gen_model_config_path("/retrain"), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.retrain(arg)).to eq(result)
    end

    it "query request POST /models/:model_id/configs/:config_id/query" do
      arg = {data: {key: "value"}}
      result = { "score" => { "Label1" => 0.5, "Label2" => -0.5, }, "classifier_result" => "Label1", }
      client.http_client.should_receive(:post).with(gen_model_config_path("/query"), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.query(arg[:data])).to eq(result)
    end

    it "trace request POST /models/:model_id/configs/:config_id/trace" do
      arg = {method: "feature_weights", data: {key: "value"}}
      result = { "result" => { "Label1" => 0.5, "Label2" => -0.5, "feature_weights" => { } }, "data" => { "key" => "value" } }
      client.http_client.should_receive(:post).with(gen_model_config_path("/trace"), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.trace(arg[:method], arg[:data])).to eq(result)
    end

    it "evaluate request POST /models/:model_id/configs/:config_id/evaluate" do
      arg = {method: "cross_validation", config: {num_folds: 2}}
      result = { "folds" => [{},{}], "result" => {} }
      client.http_client.should_receive(:post).with(gen_model_config_path("/evaluate"), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.evaluate(arg[:method], arg[:config])).to eq(result)
    end

    it "put_training_data request POST /models/:model_id/training_data" do
      arg = {data: {name: "P"}, annotation: "saitama"}
      result = {"training_data_id" => 42}
      client.http_client.should_receive(:post).with(gen_model_path("/training_data"), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.put_training_data(arg)).to eq(result)
    end

    it "list_training_data request GET /models/:model_id/training_data and set default page information" do
      result = { "num_training_data" => 1000, "page" => 1, "per_page" => 10, "training_data" => [] }
      client.http_client.should_receive(:get).with(gen_model_path("/training_data?page=1&per_page=10")).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.list_training_data).to eq(result)
    end

    it "list_training_data with page information request GET /models/:model_id/training_data" do
      arg = {page: 100, per_page: 450}
      result = { "num_training_data" => 1000, "page" => 1, "per_page" => 10, "training_data" => [] }
      client.http_client.should_receive(:get).with(gen_model_path("/training_data?page=#{arg[:page]}&per_page=#{arg[:per_page]}")).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.list_training_data(arg)).to eq(result)
    end

    it "delete_all_training_data request DELETE /models/:model_id/training_data" do
      result = {}
      client.http_client.should_receive(:delete).with(gen_model_path("/training_data")).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.delete_all_training_data).to eq(result)
    end

    it "training_data request GET /models/:model_id/training_data/:training_data_id" do
      training_data_id = 123
      result = {"data" => {"name" => "P"}, "annotation" => "saitama"}
      client.http_client.should_receive(:get).with(gen_model_path("/training_data/#{training_data_id}")).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.training_data(training_data_id)).to eq(result)
    end

    it "update_training_data request PUT /models/:model_id/training_data/:training_data_id" do
      training_data_id = 123
      arg = {data: {name: "P"}, annotation: "gunnma"}
      result = {}
      client.http_client.should_receive(:put).with(gen_model_path("/training_data/#{training_data_id}"), arg.to_json, header_for_json(arg)).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.update_training_data(training_data_id, arg)).to eq(result)
    end

    it "delete_all_training_data request DELETE /models/:model_id/training_data/:training_data_id" do
      training_data_id = 123
      result = {}
      client.http_client.should_receive(:delete).with(gen_model_path("/training_data/#{training_data_id}")).and_return(FakeResponse.new("200", "OK", result.to_json))
      expect(model.delete_training_data(training_data_id)).to eq(result)
    end
  end
end
