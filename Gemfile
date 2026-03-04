# frozen_string_literal: true

source 'https://rubygems.org'

gem "debug", platform: :mri unless ENV["CI"]

gemspec

eval_gemfile "gemfiles/rubocop.gemfile"
eval_gemfile "gemfiles/rbs.gemfile"

gem "onepassword-sdk", path: File.expand_path("~/Projects/onepassword-sdk-ruby")

local_gemfile = "#{File.dirname(__FILE__)}/Gemfile.local"

if File.exist?(local_gemfile)
  eval_gemfile local_gemfile
else
  gem 'rails', '~> 7.0'
end
