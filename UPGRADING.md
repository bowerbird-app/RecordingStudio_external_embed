# Upgrading

This gem requires `recording_studio` 6.1.0 or newer (`>= 6.1.0` in the gemspec), Rails `~> 8.1.0`, and Ruby 3.3 or newer.

Hosts on an older Recording Studio core need to:

1. Upgrade `recording_studio` to 6.1.0 or newer.
2. Run `bundle update recording_studio recording_studio_external_embed`.
3. Follow Recording Studio 6.1 upgrade notes in that gem before expecting this addon to boot.
