# frozen_string_literal: true

RecordingStudio::ExternalEmbed.configure do |config|
  config.open_timeout = 1
  config.read_timeout = 2
  config.max_bytes = 65_536
end
