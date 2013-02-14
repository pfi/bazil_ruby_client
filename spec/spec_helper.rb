require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
  add_filter 'vendor/bundle'
end

require 'rubygems'
require 'bazil'
require 'net/http'
require 'rspec'
require 'rspec/mocks'
