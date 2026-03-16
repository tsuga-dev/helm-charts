# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add per-chart changelogs and release notes from git-cliff

### Changed

- Merge branch 'main' into feat/target-allocator-support

## [opentelemetry-demo-0.7.0] - 2026-02-17

### Added

- Add resourcedetection processor for cloud metadata

### Changed

- Merge pull request #60 from tsuga-dev/feat/add-resourcedetection-processor
- Update opentelemetry-kube-stack dependency to 0.4.0 and bump chart version to 0.7.0
- Merge pull request #65 from tsuga-dev/update/opentelemetry-demo-deps-0.4.0

## [opentelemetry-demo-0.6.8] - 2026-02-16

### Added

- Add dynamic receiver discovery and multiline logs

### Changed

- Bump tsuga-spicy-gremlin to 0.1.2
- Merge pull request #56 from tsuga-dev/chore/bump-tsuga-spicy-gremlin-0.1.2
- Bump chart version to 0.6.7
- Merge pull request #57 from tsuga-dev/chore/bump-opentelemetry-demo-chart-0.6.7
- Add metrics discovery for image-provider and valkey-cart services
- Bump version
- Merge pull request #58 from tsuga-dev/feat/dynamic-receiver-discovery-multiline-logs

## [opentelemetry-demo-0.6.6] - 2026-02-16

### Changed

- Bump tsuga-spicy-gremlin verstion
- Merge pull request #52 from tsuga-dev/ab/bump-tsuga-spicy-gremlin
- Remove hardcoded OTEL env vars and add examples
- Merge pull request #54 from tsuga-dev/chore/spicy-gremlin-otel-cleanup
- Downgrade chart version to 0.6.6 and dependency version to 0.1.1
- Merge pull request #55 from tsuga-dev/fix-revert-demo-to-build-gremlin

## [opentelemetry-demo-0.6.7] - 2026-02-16

### Changed

- Leveraging new gremlin with o11y in it
- Using new spicy-gremlin version with o11y implemented
- Removing hard-coded env
- Cleaning custom env logic
- Making spicy gremlin run more often
- Merge pull request #51 from tsuga-dev/gus/gremlin-bump

## [opentelemetry-demo-0.6.4] - 2026-02-13

### Changed

- Adding tsuga-spicy-gremlin
- Revert "Collecting more data out of kafka, redis, postgres, envoy"
- Merge pull request #49 from tsuga-dev/revert-46-gus/improve-receiver
- Merging main
- Merge pull request #48 from tsuga-dev/gus/automated-failures

## [opentelemetry-demo-0.6.2] - 2026-02-12

### Changed

- Collecting more data out of kafka, redis, postgres, envoy
- Merge pull request #46 from tsuga-dev/gus/improve-receiver

## [opentelemetry-demo-0.6.1] - 2026-01-14

### Changed

- Update opentelemetry-demo to version 0.6.1, enhance PostgreSQL logging configuration by adding log_min_duration_statement and log_line_prefix settings, and update README with the new version badge.
- Merge pull request #40 from tsuga-dev/feat-improve-pg-logging

## [opentelemetry-demo-0.6.0] - 2026-01-14

### Changed

- Enable postgresql log collection and log_statement all
- Update opentelemetry-demo to version 0.40.0, enhancing PostgreSQL log collection with new pod annotations and image overrides for product-reviews component.
- Update opentelemetry-demo to version 0.6.0, bump opentelemetry-kube-stack to version 0.2.15, and modify logging configuration to disable log collection while adding support for log volumes.
- Merge pull request #39 from tsuga-dev/Posgresql-tracing

## [opentelemetry-demo-0.5.0] - 2026-01-06

### Changed

- Update opentelemetry-kube-stack dependency to 0.2.12 and bump chart version to 0.5.0
- Merge pull request #31 from tsuga-dev/update/opentelemetry-demo-deps-0.2.12

## [opentelemetry-demo-0.4.0] - 2026-01-05

### Changed

- Update opentelemetry-kube-stack dependency to 0.2.11 and bump chart version to 0.4.0
- Merge pull request #30 from tsuga-dev/update/opentelemetry-demo-deps-0.2.11

## [opentelemetry-demo-0.3.0] - 2026-01-05

### Changed

- Bump chart version to 0.2.11 and update spanmetrics connector configuration
- Merge pull request #27 from tsuga-dev/bump-version-and-update-daemonset-config
- Update opentelemetry-kube-stack dependency to 0.2.11 and bump chart version to 0.3.0
- Merge pull request #28 from tsuga-dev/update/opentelemetry-demo-deps-0.2.11

## [opentelemetry-demo-0.2.0] - 2025-12-18

### Changed

- Update opentelemetry-kube-stack dependency to 0.2.10 and bump chart version to 0.2.0
- Merge pull request #26 from tsuga-dev/update/opentelemetry-demo-deps-0.2.10

## [opentelemetry-demo-0.1.4] - 2025-12-17

### Changed

- Bump dependency version
- Merge pull request #24 from tsuga-dev/update-kubestack-version

## [opentelemetry-demo-0.1.3] - 2025-12-16

### Changed

- Update opentelemetry-kube-stack dependency to version 0.2.8 and add collectLogs option in values.yaml
- Merge pull request #22 from tsuga-dev/remove-log-collection

## [opentelemetry-demo-0.1.2] - 2025-12-15

### Changed

- Update opentelemetry-kube-stack dependency version to 0.2.7 in Chart.yaml
- Bump version
- Merge pull request #20 from tsuga-dev/update-kube-stack-dependency

## [opentelemetry-demo-0.1.1] - 2025-12-12

### Changed

- Add OpenTelemetry demo Helm chart
- Merge pull request #12 from tsuga-dev/opentelemetry-demo-chart
- Add pod annotations for OpenTelemetry components in values.yaml
- Add default example
- Bump versions
- Merge pull request #14 from tsuga-dev/otel-demo-improvement
- Revert "Otel-demo-improvement"
- Merge pull request #15 from tsuga-dev/revert-14-otel-demo-improvement
- Enhance OpenTelemetry demo chart and CI/CD configuration
- Merge pull request #18 from tsuga-dev/Otel-demo-improvment

[unreleased]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.7.0..HEAD
[opentelemetry-demo-0.7.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.8..opentelemetry-demo-0.7.0
[opentelemetry-demo-0.6.8]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.6..opentelemetry-demo-0.6.8
[opentelemetry-demo-0.6.6]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.7..opentelemetry-demo-0.6.6
[opentelemetry-demo-0.6.7]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.4..opentelemetry-demo-0.6.7
[opentelemetry-demo-0.6.4]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.2..opentelemetry-demo-0.6.4
[opentelemetry-demo-0.6.2]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.1..opentelemetry-demo-0.6.2
[opentelemetry-demo-0.6.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.0..opentelemetry-demo-0.6.1
[opentelemetry-demo-0.6.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.5.0..opentelemetry-demo-0.6.0
[opentelemetry-demo-0.5.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.4.0..opentelemetry-demo-0.5.0
[opentelemetry-demo-0.4.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.3.0..opentelemetry-demo-0.4.0
[opentelemetry-demo-0.3.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.2.0..opentelemetry-demo-0.3.0
[opentelemetry-demo-0.2.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.4..opentelemetry-demo-0.2.0
[opentelemetry-demo-0.1.4]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.3..opentelemetry-demo-0.1.4
[opentelemetry-demo-0.1.3]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.2..opentelemetry-demo-0.1.3
[opentelemetry-demo-0.1.2]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.1..opentelemetry-demo-0.1.2
[opentelemetry-demo-0.1.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.0..opentelemetry-demo-0.1.1

