# frozen_string_literal: true

require "rails/generators"

module RecordingStudio
  module ExternalEmbed
    module Generators
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path("templates", __dir__)

        desc "Install RecordingStudio::ExternalEmbed into a host application"

        class_option :mount_path, type: :string, default: "/recording_studio_external_embed",
                                  desc: "Route prefix used when mounting the engine"

        def mount_engine
          route %(mount RecordingStudio::ExternalEmbed::Engine, at: "#{options[:mount_path]}")
        end

        def copy_initializer
          template "initializer.rb", "config/initializers/recording_studio_external_embed.rb"
        end
      end
    end
  end
end
