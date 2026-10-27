# frozen_string_literal: true

# Sibling git gems still declare `recording_studio` `~> 4.x`. That range
# rejects 6.1.0. Rewrite the requirement on the existing dependency object
# when Bundler reads the gemspec. Return the same array `add_dependency`
# appends to.
module WidenRecordingStudioRequirement
  COMPATIBLE_VERSION = Gem::Version.new("6.1.0")
  WIDENED = Gem::Requirement.new(">= 4.1")

  module SpecificationDependencies
    def dependencies
      deps = super
      WidenRecordingStudioRequirement.widen_all(deps)
      deps
    end
  end

  def self.widen_all(deps)
    deps.each do |dependency|
      next unless dependency.name == "recording_studio"

      requirement = dependency.requirement
      next if requirement.satisfied_by?(COMPATIBLE_VERSION)

      dependency.instance_variable_set(:@requirement, WIDENED)
    end
  end
end

Gem::Specification.prepend(WidenRecordingStudioRequirement::SpecificationDependencies)
