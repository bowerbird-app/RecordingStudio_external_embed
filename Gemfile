# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# flat_pack and recording_studio are not published to RubyGems.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.356"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.7.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
