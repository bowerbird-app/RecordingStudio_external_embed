# frozen_string_literal: true

require_relative "../tailwind_gem_sources"

namespace :tailwindcss do
  desc "Write @source globs for the installed FlatPack and Recording Studio gems"
  task gem_sources: :environment do
    TailwindGemSources.write!(Rails.root.join("app/assets/builds/tailwind/gem_sources.css"))
  end
end

%w[build watch].each do |name|
  Rake::Task["tailwindcss:#{name}"].enhance([ "tailwindcss:gem_sources" ])
end
