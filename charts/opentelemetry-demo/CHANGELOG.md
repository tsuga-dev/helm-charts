# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [opentelemetry-demo-0.9.4] - 2026-06-11

### Added
- PostgreSQL deep monitoring via stored functions and receiver_creator (#90) by @abruneau in [#90](https://github.com/tsuga-dev/helm-charts/pull/90)

## [opentelemetry-demo-0.9.3] - 2026-06-08

### Added
- Add PostgreSQL top queries metrics via sqlquery receiver (#88) by @abruneau in [#88](https://github.com/tsuga-dev/helm-charts/pull/88)

## [opentelemetry-demo-0.9.2] - 2026-06-05

### Fixed
- Fix sql statement (#87) by @abruneau in [#87](https://github.com/tsuga-dev/helm-charts/pull/87)

## [opentelemetry-demo-0.9.1] - 2026-06-05

### Fixed
- Fix postgresql subPath volume mount conflict (#86) by @abruneau in [#86](https://github.com/tsuga-dev/helm-charts/pull/86)

## [opentelemetry-demo-0.9.0] - 2026-06-05

### Added
- Add pod watch, memory metrics, bump to 0.7.0 (#84) by @abruneau in [#84](https://github.com/tsuga-dev/helm-charts/pull/84)

### Changed
- Standardize YAML formatting checks (#82) by @abruneau in [#82](https://github.com/tsuga-dev/helm-charts/pull/82)
- Update/opentelemetry demo deps 0.7.0 and pg stats (#85) by @abruneau in [#85](https://github.com/tsuga-dev/helm-charts/pull/85)

## [opentelemetry-demo-0.8.0] - 2026-04-28

### Added
- Add per-chart changelogs and release notes from git-cliff by @abruneau
- Add k8s metrics and objects for otel demo by @kkontoudi

### Changed
- Update changelog templates and enhance validation by @abruneau

### New Contributors
* @kkontoudi made their first contribution in [#79](https://github.com/tsuga-dev/helm-charts/pull/79)

## [opentelemetry-demo-0.7.0] - 2026-02-17

### Added
- Add resourcedetection processor for cloud metadata by @abruneau

### Changed
- Update opentelemetry-kube-stack dependency to 0.4.0 and bump chart version to 0.7.0 by @abruneau

## [opentelemetry-demo-0.6.8] - 2026-02-16

### Added
- Add dynamic receiver discovery and multiline logs by @abruneau

### Changed
- Bump tsuga-spicy-gremlin to 0.1.2 by @abruneau
- Bump chart version to 0.6.7 by @abruneau
- Add metrics discovery for image-provider and valkey-cart services by @abruneau
- Bump version by @abruneau

## [opentelemetry-demo-0.6.6] - 2026-02-16

### Changed
- Bump tsuga-spicy-gremlin verstion by @abruneau
- Remove hardcoded OTEL env vars and add examples by @abruneau
- Downgrade chart version to 0.6.6 and dependency version to 0.1.1 by @abruneau

## [opentelemetry-demo-0.6.7] - 2026-02-16

### Changed
- Leveraging new gremlin with o11y in it by @gus-tsuga
- Using new spicy-gremlin version with o11y implemented by @gus-tsuga
- Removing hard-coded env by @gus-tsuga
- Cleaning custom env logic by @gus-tsuga
- Making spicy gremlin run more often by @gus-tsuga

## [opentelemetry-demo-0.6.4] - 2026-02-13

### Changed
- Adding tsuga-spicy-gremlin by @gus-tsuga
- Revert "Collecting more data out of kafka, redis, postgres, envoy" by @gus-tsuga

## [opentelemetry-demo-0.6.2] - 2026-02-12

### Changed
- Collecting more data out of kafka, redis, postgres, envoy by @gus-tsuga

### New Contributors
* @gus-tsuga made their first contribution in [#46](https://github.com/tsuga-dev/helm-charts/pull/46)

## [opentelemetry-demo-0.6.1] - 2026-01-14

### Changed
- Update opentelemetry-demo to version 0.6.1, enhance PostgreSQL logging configuration by adding log_min_duration_statement and log_line_prefix settings, and update README with the new version badge. by @abruneau

## [opentelemetry-demo-0.6.0] - 2026-01-14

### Changed
- Enable postgresql log collection and log_statement all by @abruneau
- Update opentelemetry-demo to version 0.40.0, enhancing PostgreSQL log collection with new pod annotations and image overrides for product-reviews component. by @abruneau
- Update opentelemetry-demo to version 0.6.0, bump opentelemetry-kube-stack to version 0.2.15, and modify logging configuration to disable log collection while adding support for log volumes. by @abruneau

## [opentelemetry-demo-0.5.0] - 2026-01-06

### Changed
- Update opentelemetry-kube-stack dependency to 0.2.12 and bump chart version to 0.5.0 by @abruneau

## [opentelemetry-demo-0.4.0] - 2026-01-05

### Changed
- Update opentelemetry-kube-stack dependency to 0.2.11 and bump chart version to 0.4.0 by @abruneau

## [opentelemetry-demo-0.3.0] - 2026-01-05

### Changed
- Bump chart version to 0.2.11 and update spanmetrics connector configuration by @abruneau
- Update opentelemetry-kube-stack dependency to 0.2.11 and bump chart version to 0.3.0 by @abruneau

## [opentelemetry-demo-0.2.0] - 2025-12-18

### Changed
- Update opentelemetry-kube-stack dependency to 0.2.10 and bump chart version to 0.2.0 by @abruneau

## [opentelemetry-demo-0.1.4] - 2025-12-17

### Changed
- Bump dependency version by @abruneau

## [opentelemetry-demo-0.1.3] - 2025-12-16

### Changed
- Update opentelemetry-kube-stack dependency to version 0.2.8 and add collectLogs option in values.yaml by @abruneau

## [opentelemetry-demo-0.1.2] - 2025-12-15

### Changed
- Update opentelemetry-kube-stack dependency version to 0.2.7 in Chart.yaml by @abruneau
- Bump version by @abruneau

## [opentelemetry-demo-0.1.1] - 2025-12-12

### Changed
- Add OpenTelemetry demo Helm chart by @abruneau
- Add pod annotations for OpenTelemetry components in values.yaml by @abruneau
- Add default example by @abruneau
- Bump versions by @abruneau
- Revert "Otel-demo-improvement" by @abruneau
- Enhance OpenTelemetry demo chart and CI/CD configuration by @abruneau
[opentelemetry-demo-0.9.4]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.9.3...opentelemetry-demo-0.9.4

[opentelemetry-demo-0.9.3]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.9.2...opentelemetry-demo-0.9.3

[opentelemetry-demo-0.9.2]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.9.1...opentelemetry-demo-0.9.2

[opentelemetry-demo-0.9.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.9.0...opentelemetry-demo-0.9.1

[opentelemetry-demo-0.9.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.8.0...opentelemetry-demo-0.9.0

[opentelemetry-demo-0.8.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.7.0...opentelemetry-demo-0.8.0

[opentelemetry-demo-0.7.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.8...opentelemetry-demo-0.7.0

[opentelemetry-demo-0.6.8]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.6...opentelemetry-demo-0.6.8

[opentelemetry-demo-0.6.6]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.7...opentelemetry-demo-0.6.6

[opentelemetry-demo-0.6.7]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.4...opentelemetry-demo-0.6.7

[opentelemetry-demo-0.6.4]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.2...opentelemetry-demo-0.6.4

[opentelemetry-demo-0.6.2]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.1...opentelemetry-demo-0.6.2

[opentelemetry-demo-0.6.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.6.0...opentelemetry-demo-0.6.1

[opentelemetry-demo-0.6.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.5.0...opentelemetry-demo-0.6.0

[opentelemetry-demo-0.5.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.4.0...opentelemetry-demo-0.5.0

[opentelemetry-demo-0.4.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.3.0...opentelemetry-demo-0.4.0

[opentelemetry-demo-0.3.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.2.0...opentelemetry-demo-0.3.0

[opentelemetry-demo-0.2.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.4...opentelemetry-demo-0.2.0

[opentelemetry-demo-0.1.4]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.3...opentelemetry-demo-0.1.4

[opentelemetry-demo-0.1.3]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.2...opentelemetry-demo-0.1.3

[opentelemetry-demo-0.1.2]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.1...opentelemetry-demo-0.1.2

[opentelemetry-demo-0.1.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-demo-0.1.0...opentelemetry-demo-0.1.1

<!-- generated by git-cliff -->
