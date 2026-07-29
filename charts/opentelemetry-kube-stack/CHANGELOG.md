# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [opentelemetry-kube-stack-0.11.0] - 2026-07-29

### Breaking Changes
- **BREAKING** Raise the collector version floor to 0.157.0
  Pinning agent.image, cluster.image, statefulset.image or the top-level image to a tag below 0.157.0 now fails the render instead of letting the collector crash-loop on an unknown component type. Move to a 0.157.0+ image, or stay on chart 0.10.x.
- **BREAKING** Rename the resourcedetection and cumulativetodelta processors to their canonical types
  resource_detection has been canonical since collector 0.153.0, cumulative_to_delta since 0.157.0; the old spellings are deprecated aliases that log a warning on every startup. If your own extraProcessors or extraPipelines reference the old names, update them: a pipeline entry is matched against literal config keys, so a stale reference fails the collector at startup even though the render succeeds.

### Changed
- Pin a concrete 0.157.0 image tag on all three collectors, replacing the untagged default

### Fixed
- cluster.allocatableTypesToReport now defaults to ephemeral-storage instead of storage, which is not a node allocatable type and silently produced no metric
- Warning events are no longer reported a second time when the API server expires them
- Drop the net.host.name pod association from the statefulset collector, which never matched a record
- Stop suffixed image tags such as 0.156.0-amd64 from bypassing the version floor check
- Correct the documented image defaults for all three collectors, and the purpose of the top-level image key
- Fix the extra-service example, which referenced hostmetrics and otlphttp/tsuga rather than the keys the chart renders
- Correct the collector self-telemetry notes: internal metrics do reach Tsuga, and the operator does not override a user-supplied telemetry reader
- Document why self-telemetry bypasses the pipelines, and why its endpoint carries the signal path while the exporter's does not

### Upgrade notes
- Collector images now carry an explicit tag, so Kubernetes resolves imagePullPolicy to IfNotPresent instead of Always. Pod restarts no longer depend on the registry being reachable, and the running collector can no longer drift away from the version the floor check validated. If you mirror images, make sure 0.157.0 is present in your registry before upgrading.
- Collector 0.157.0 aggregates system.cpu.time and system.cpu.utilization across logical CPUs: the cpu attribute is now opt-in and absent by default. Anything grouping those metrics by cpu needs updating. Restore it by setting the metric's attributes to [cpu, state] through agent.config.extraReceivers.
- Collector 0.157.0 enables system.cpu.logical.count by default, adding one series per node.
- cluster.allocatableTypesToReport now yields k8s.node.allocatable_ephemeral_storage where it previously yielded nothing.
- Collector self-telemetry still uses the legacy inline-map resource format. The collector prefers a resource.attributes array, but the bundled operator cannot parse it and would drop the block entirely, so that migration waits for the operator bump.

## [opentelemetry-kube-stack-0.10.6] - 2026-07-29

### Added
- agent.kubeletStats.metricGroups, for controlling kubelet metric cardinality
- tsuga.encoding and tsuga.compression, for the OTLP exporter wire format
- Collection intervals: agent.kubeletStats.collectionInterval, agent.hostMetrics.collectionInterval, cluster.collectionInterval, statefulset.scrapeInterval
- agent.fileLog.include and agent.fileLog.exclude, for scoping log collection
- agent.spanMetrics.enabled and agent.spanMetrics.dimensions
- agent.otlp.grpcEndpoint, agent.otlp.httpEndpoint, and per-collector healthCheckEndpoint
- Kubelet TLS settings: agent.kubeletStats.authType, insecureSkipVerify and caFile
- Shared k8sAttributes.metadata and batch settings
- cluster.nodeConditionsToReport and cluster.allocatableTypesToReport

### Fixed
- The cluster receiver and statefulset collectors now get a health_check extension, so they have a liveness probe
- agent.fileLog.exclude is no longer discarded when agent.collectOtelLogs is true

## [opentelemetry-kube-stack-0.10.5] - 2026-07-28

### Added
- Collect Kubernetes Warning events, filtered at the API server, off by default

### Changed
- Document what disabling agent.kubeletStats.usePodsEndpoint costs, and keep long values comments out of the generated README table

## [opentelemetry-kube-stack-0.10.4] - 2026-07-28

### Added
- Collect container and volume metrics and limit/request utilization from the kubelet
- agent.kubeletStats.usePodsEndpoint, for clusters that cannot grant nodes/proxy

## [opentelemetry-kube-stack-0.10.3] - 2026-07-28

### Added
- Optional cloud and host resource detection, off by default

## [opentelemetry-kube-stack-0.10.2] - 2026-07-28

### Fixed
- Raise the collector version floor to 0.152.0, the version the configured component names require

## [opentelemetry-kube-stack-0.10.1] - 2026-07-27

### Added
- Describe the collectors as configured by @gus-tsuga

### Fixed
- Run memory_limiter first and batch last in every pipeline by @gus-tsuga
- Stamp k8s.node.name on telemetry that arrives without one by @gus-tsuga
- Drop dead and inert collector config by @gus-tsuga
- Pin the cluster receiver to a single replica by @gus-tsuga
- Exclude pseudo filesystems from the hostmetrics filesystem scraper by @gus-tsuga

### Changed
- Bump to 0.10.1 and regenerate the changelog by @gus-tsuga

## [opentelemetry-kube-stack-0.10.0] - 2026-07-27

### Breaking Changes
- **BREAKING** Require clusterName by @gus-tsuga
  Installs and upgrades now fail if clusterName is empty. Pass --set clusterName=<name>; --reuse-values does not supply it, because the stored value is the empty string.

### Added
- Pass clusterName in every documented install path by @gus-tsuga

### Changed
- Group breaking changes in generated release notes by @gus-tsuga

## [opentelemetry-kube-stack-0.9.0] - 2026-07-16

### Added
- Enable cluster.collectk8sobjects by default by @gus-tsuga

### Fixed
- Guard cluster receiver pipelines with memory_limiter by @gus-tsuga

## [opentelemetry-kube-stack-0.7.4] - 2026-07-13

### Fixed
- Render service.telemetry.resource as a map (#111) by @abruneau in [#111](https://github.com/tsuga-dev/helm-charts/pull/111)

### Changed
- Making placeholders explicits by @gus-tsuga

## [opentelemetry-kube-stack-0.7.3] - 2026-07-01

### Added
- Align demo and kube-stack with OTel naming conventions (#95) by @abruneau in [#95](https://github.com/tsuga-dev/helm-charts/pull/95)

### Fixed
- List-form telemetry headers + collector version guard (#107) by @abruneau in [#107](https://github.com/tsuga-dev/helm-charts/pull/107)

### Changed
- Fix Old otel conventions (#98) by @abruneau in [#98](https://github.com/tsuga-dev/helm-charts/pull/98)
- Docs/readme charts update (#104) by @abruneau in [#104](https://github.com/tsuga-dev/helm-charts/pull/104)
- Remove payment log pod annotation and default to contrib image (#106) by @abruneau in [#106](https://github.com/tsuga-dev/helm-charts/pull/106)

## [opentelemetry-kube-stack-0.7.2] - 2026-06-11

### Changed
- Fix the configs with the new naming conventions from Otel (#93) by @abruneau in [#93](https://github.com/tsuga-dev/helm-charts/pull/93)

## [opentelemetry-kube-stack-0.7.1] - 2026-06-08

### Added
- Add cluster name and instance ID to collector telemetry (#89) by @abruneau in [#89](https://github.com/tsuga-dev/helm-charts/pull/89)

## [opentelemetry-kube-stack-0.7.0] - 2026-06-05

### Added
- Add pod watch, memory metrics, bump to 0.7.0 (#84) by @abruneau in [#84](https://github.com/tsuga-dev/helm-charts/pull/84)

### Fixed
- Export collector metrics through OTLP (#83) by @abruneau in [#83](https://github.com/tsuga-dev/helm-charts/pull/83)

## [opentelemetry-kube-stack-0.6.3] - 2026-05-20

### Added
- Add tusga-less example and update chart changelogs by @abruneau

### Changed
- Standardize YAML formatting checks (#82) by @abruneau in [#82](https://github.com/tsuga-dev/helm-charts/pull/82)
- Update default spanmetrics dims (#77) by @gus-tsuga in [#77](https://github.com/tsuga-dev/helm-charts/pull/77)

## [opentelemetry-kube-stack-0.6.2] - 2026-03-16

### Added
- Add per-chart changelogs and release notes from git-cliff by @abruneau
- Add per-component Tsuga exporter toggles by @abruneau

### Changed
- Update changelog templates and enhance validation by @abruneau

## [opentelemetry-kube-stack-0.6.1] - 2026-03-16

### Added
- Add k8sattributes to cluster receiver and k8s-objects example by @abruneau

### Changed
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.6.0] - 2026-03-13

### Added
- Enhance cluster receiver and daemonset metrics collection by @gus-tsuga
- Add permissions for Kubernetes events collection by @gus-tsuga

### Changed
- Bump chart version to 0.6.0 and update documentation by @gus-tsuga
- Make collectk8sobjects optional by @abruneau

## [opentelemetry-kube-stack-0.5.1] - 2026-03-12

### Added
- Add extraLabelMapping and extraAnnotationsMapping to statefulset by @abruneau

### Changed
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.4.1] - 2026-02-27

### Added
- Add statefulset collector template by @abruneau
- Add TargetAllocator CR template by @abruneau
- Complete targetAllocator and statefulset values by @abruneau
- Fix statefulset values documentation by @abruneau
- Add PrometheusCR RBAC rules for Target Allocator by @abruneau
- Add schema for targetAllocator and statefulset values by @abruneau
- Add target-allocator example by @abruneau

### Fixed
- Make replicas conditional, document TA coupling by @abruneau
- Guard TargetAllocator serviceAccount on serviceAccount.create by @abruneau
- Tolerations type, add serviceAccount guard test by @abruneau
- Add TA endpoint, POD_NAME, memory_limiter to statefulset collector by @abruneau
- Add EndpointSlices RBAC for TargetAllocator service discovery by @abruneau
- Fix replicas schema type (string → integer) by @abruneau
- Gate EndpointSlices RBAC on targetAllocator.enabled by @abruneau
- Add placeholder scrape_config for TargetAllocator override by @abruneau
- Shorten statefulset CR name to avoid 63-char label limit by @abruneau
- Add net.host.name and cumulativetodelta to statefulset collector by @abruneau
- Fix tolerations type for agent and cluster by @abruneau

### Changed
- Add statefulset collector-TA link tests by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.4.0] - 2026-02-17

### Added
- Add dynamic receiver discovery and multiline logs by @abruneau
- Make clusterName optional with warning by @abruneau
- Document operator and cert-manager requirements by @abruneau

### Fixed
- Update gitignore and operator condition by @abruneau

### Changed
- Add auto-instrumentation examples and testing framework by @abruneau
- Remove unused otel-crds dependency by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.3.0] - 2026-02-02

### Added
- Add auto-instrumentation support by @abruneau

## [opentelemetry-kube-stack-0.2.16] - 2026-02-02

### Added
- Configure batch processor with optimized settings by @abruneau

### Changed
- Merge commit '6ede1ed41f9b4daef4edba0a2907b60abe42b25c' by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.2.15] - 2026-01-14

### Changed
- Add 'addLogsVolumes' option to agent configuration for log collection in OpenTelemetry stack by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.2.14] - 2026-01-12

### Fixed
- Fix custom config not being taken in count by @abruneau

### Changed
- Enhance OpenTelemetry configuration by adding k8s_observer extension for improved Kubernetes resource observation. Update daemonset and service templates to include new logging receiver and adjust extraExtensions handling. by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.2.13] - 2026-01-12

### Changed
- Update OpenTelemetry configuration in README, schema, and values files to change 'extraExtensions' from object to array type for both agent and cluster services. by @abruneau
- Bump opentelemetry-kube-stack chart version to 0.2.13 by @abruneau

## [opentelemetry-kube-stack-0.2.12] - 2026-01-05

### Changed
- Bump chart version to 0.2.12 and remove 'exclude_dimensions' from daemonset configuration by @abruneau

## [opentelemetry-kube-stack-0.2.11] - 2026-01-05

### Changed
- Bump chart version to 0.2.11 and update spanmetrics connector configuration by @abruneau

## [opentelemetry-kube-stack-0.2.10] - 2025-12-17

### Changed
- Update OpenTelemetry kube-stack to version 0.2.10 and modify configuration to use NODE_IP for endpoint resolution by @abruneau

## [opentelemetry-kube-stack-0.2.9] - 2025-12-17

### Changed
- Add host filesystem support in daemonset configuration by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.2.8] - 2025-12-16

### Changed
- Add conditional log collection configuration in daemonset template by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.2.7] - 2025-12-15

### Changed
- Add Helm ownership annotations to all resources by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.2.6] - 2025-12-12

### Changed
- Fix regex in cluster name validation to allow underscores in addition to hyphens. by @abruneau
- Add annotations to OpenTelemetry configuration in _config.tpl by @abruneau
- Add OpenTelemetry configuration schema and enhance values.yaml by @abruneau
- Fix templates by @abruneau
- Add extraConnectors configuration to OpenTelemetry schema and values.yaml by @abruneau
- Fix _service.tpl by @abruneau
- Bump versions by @abruneau
- Update Doc by @abruneau
- Revert "Otel-demo-improvement" by @abruneau
- Add OpenTelemetry configuration and CI enhancements by @abruneau

## [opentelemetry-kube-stack-0.2.5] - 2025-10-31

### Changed
- Update OpenTelemetry Kube Stack to v0.2.5 by @abruneau
- Remove duplicated attributes by @abruneau
- Fix grammar by @abruneau
- Fix indentation in _config.tpl to properly align k8sattributes and labels sections by @abruneau

## [opentelemetry-kube-stack-0.2.4] - 2025-10-17

### Changed
- Remove 'k8sattributes' processor from cluster receiver configuration in example YAML files and Helm template. by @abruneau
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.2.3] - 2025-10-17

### Changed
- Add collection settings configuration to deploy script by @abruneau
- Add cluster name configuration to deploy script and Helm templates by @abruneau
- Update release workflow and increment OpenTelemetry Kube Stack chart version by @abruneau

## [opentelemetry-kube-stack-0.2.2] - 2025-10-07

### Changed
- Bump version by @abruneau

## [opentelemetry-kube-stack-0.2.1] - 2025-10-06

### Changed
- Enhance OpenTelemetry Kube Stack configuration and examples by @abruneau
- Update Helm chart and README for Tsuga integration by @abruneau

## [opentelemetry-kube-stack-0.2.0] - 2025-10-06

### Changed
- First commit by @abruneau
- Add Makefile for example generation and validation; update Helm chart configurations by @abruneau
[opentelemetry-kube-stack-0.10.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.10.0...opentelemetry-kube-stack-0.10.1

[opentelemetry-kube-stack-0.10.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.9.0...opentelemetry-kube-stack-0.10.0

[opentelemetry-kube-stack-0.9.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.7.4...opentelemetry-kube-stack-0.9.0

[opentelemetry-kube-stack-0.7.4]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.7.3...opentelemetry-kube-stack-0.7.4

[opentelemetry-kube-stack-0.7.3]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.7.2...opentelemetry-kube-stack-0.7.3

[opentelemetry-kube-stack-0.7.2]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.7.1...opentelemetry-kube-stack-0.7.2

[opentelemetry-kube-stack-0.7.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.7.0...opentelemetry-kube-stack-0.7.1

[opentelemetry-kube-stack-0.7.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.6.3...opentelemetry-kube-stack-0.7.0

[opentelemetry-kube-stack-0.6.3]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.6.2...opentelemetry-kube-stack-0.6.3

[opentelemetry-kube-stack-0.6.2]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.6.1...opentelemetry-kube-stack-0.6.2

[opentelemetry-kube-stack-0.6.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.6.0...opentelemetry-kube-stack-0.6.1

[opentelemetry-kube-stack-0.6.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.5.1...opentelemetry-kube-stack-0.6.0

[opentelemetry-kube-stack-0.5.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.5.0...opentelemetry-kube-stack-0.5.1

[opentelemetry-kube-stack-0.5.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.4.1...opentelemetry-kube-stack-0.5.0

[opentelemetry-kube-stack-0.4.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.4.0...opentelemetry-kube-stack-0.4.1

[opentelemetry-kube-stack-0.4.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.3.0...opentelemetry-kube-stack-0.4.0

[opentelemetry-kube-stack-0.3.0]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.16...opentelemetry-kube-stack-0.3.0

[opentelemetry-kube-stack-0.2.16]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.15...opentelemetry-kube-stack-0.2.16

[opentelemetry-kube-stack-0.2.15]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.14...opentelemetry-kube-stack-0.2.15

[opentelemetry-kube-stack-0.2.14]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.13...opentelemetry-kube-stack-0.2.14

[opentelemetry-kube-stack-0.2.13]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.12...opentelemetry-kube-stack-0.2.13

[opentelemetry-kube-stack-0.2.12]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.11...opentelemetry-kube-stack-0.2.12

[opentelemetry-kube-stack-0.2.11]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.10...opentelemetry-kube-stack-0.2.11

[opentelemetry-kube-stack-0.2.10]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.9...opentelemetry-kube-stack-0.2.10

[opentelemetry-kube-stack-0.2.9]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.8...opentelemetry-kube-stack-0.2.9

[opentelemetry-kube-stack-0.2.8]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.7...opentelemetry-kube-stack-0.2.8

[opentelemetry-kube-stack-0.2.7]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.6...opentelemetry-kube-stack-0.2.7

[opentelemetry-kube-stack-0.2.6]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.5...opentelemetry-kube-stack-0.2.6

[opentelemetry-kube-stack-0.2.5]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.4...opentelemetry-kube-stack-0.2.5

[opentelemetry-kube-stack-0.2.4]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.3...opentelemetry-kube-stack-0.2.4

[opentelemetry-kube-stack-0.2.3]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.2...opentelemetry-kube-stack-0.2.3

[opentelemetry-kube-stack-0.2.2]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.1...opentelemetry-kube-stack-0.2.2

[opentelemetry-kube-stack-0.2.1]: https://github.com/tsuga-dev/helm-charts/compare/opentelemetry-kube-stack-0.2.0...opentelemetry-kube-stack-0.2.1

<!-- generated by git-cliff -->
