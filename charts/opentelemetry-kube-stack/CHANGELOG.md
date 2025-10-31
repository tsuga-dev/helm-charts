# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.5] - 2025-10-31

### Added
- Support for `extraExtensions` in agent configuration, allowing additional extensions to be added alongside the default health_check extension
- Support for `service.extraExtensions` in agent service configuration
- Label mapping support for k8sattributes processor via `labelMapping` values field
- Conditional log collection support with `collectLogs` configuration option (replaces `collectKubernetesLogs`)
- k8sattributes processor added to cluster receiver for enhanced Kubernetes metadata extraction
- Default label extraction for OpenTelemetry resource attributes:
  - `service.name` from `resource.opentelemetry.io/service.name`
  - `service.version` from `resource.opentelemetry.io/service.version`
  - `env` from `resource.opentelemetry.io/env`
  - `team` from `resource.opentelemetry.io/team`
- Updated rendered examples for create-secret, default, and otel-demo configurations

### Changed
- Chart version bumped from 0.2.4 to 0.2.5
- Replaced `collectKubernetesLogs` configuration with `collectLogs` for more flexible log collection control
- Filelog receiver is now conditionally included based on `collectLogs` setting

### Miscellaneous
- Added .gitignore file to the repository

