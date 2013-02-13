require 'bazil'
require 'net/http'
require 'rspec'
require 'spec_helper'

describe Bazil::Client do
  describe Bazil::Client::Options, "with empty option provide default" do
    let(:option) { Bazil::Client::Options.new({}) }

    it "host name" do
      expect(option.host).to eq('asp-bazil.preferred.jp')
    end

    it "port name" do
      expect(option.port).to eq(443)
    end

    it "scheme" do
      expect(option.scheme).to eq('https')
    end

    it "ca_file" do
      expect(option.ca_file).to eq(nil)
    end

    it "ssl_version" do
      expect(option.ssl_version).to eq('TLSv1')
    end

    it "verify_mode" do
      expect(option.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
    end
  end

  describe Bazil::Client::Options, "with all options can parse" do
    let(:option) {
      Bazil::Client::Options.new({
        url: 'http://localhost:8080/',
        ca_file: __FILE__, # always exists and absolute path
        ssl_version: :SSLv3,
        skip_verify: true
      })
    }

    it "host name" do
      expect(option.host).to eq('localhost')
    end

    it "port name" do
      expect(option.port).to eq(8080)
    end

    it "scheme" do
      expect(option.scheme).to eq('http')
    end

    it "ca_file" do
      expect(option.ca_file).to eq(__FILE__)
    end

    it "ssl_version" do
      expect(option.ssl_version).to eq('SSLv3')
    end

    it "skip_verify" do
      expect(option.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
    end
  end

  describe Bazil::Client::Options, "'s url" do
    it "can derivate HTTP port number from http schema" do
      option = Bazil::Client::Options.new(url: 'http://localhost/')
      expect(option.port).to eq(80)
    end

    it "can derivate HTTPS port number from https schem" do
      option = Bazil::Client::Options.new(url: 'https://localhost/')
      expect(option.port).to eq(443)
    end

    it "can overwrite port number for http schema" do
      option = Bazil::Client::Options.new(url: 'http://localhost:443/')
      expect(option.port).to eq(443)
    end

    it "can overwrite port number for https schem" do
      option = Bazil::Client::Options.new(url: 'https://localhost:80/')
      expect(option.port).to eq(80)
    end
  end

  describe Bazil::Client::Options, "will raise error for" do
    it "invalid url" do
      proc {
        Bazil::Client::Options.new(url: 42)
      }.should raise_error
    end

    it "empty url" do
      proc {
        Bazil::Client::Options.new(url: '')
      }.should raise_error
    end

    it "invalid port" do
      proc {
        Bazil::Client::Options.new(url: 'http://localhost:ssl_port_please/')
      }.should raise_error
    end

    it "unsupported scheme" do
      proc {
        Bazil::Client::Options.new(url: 'saitama://localhost:80/')
      }.should raise_error
    end

    it "non string ca_file" do
      proc {
        Bazil::Client::Options.new(ca_file: 42)
      }.should raise_error
    end

    it "relative ca_file" do
      proc {
        Bazil::Client::Options.new(ca_file: './' + File::basename(__FILE__))
      }.should raise_error
    end

    it "non exists ca_file" do
      proc {
        Bazil::Client::Options.new(ca_file: '/:never:/:exist:/:file:/:path:')
      }.should raise_error
    end

    it "invalid ssl_version" do
      proc {
        Bazil::Client::Options.new(ssl_version: 3.14)
      }.should raise_error
    end

    it "unsupported ssl_version" do
      proc {
        Bazil::Client::Options.new(ssl_version: :SSL_version_saitama)
      }.should raise_error
    end

    it "non-boolean skip_verify" do
      proc {
        Bazil::Client::Options.new(skip_verify: "YES")
      }.should raise_error
    end
  end
end
