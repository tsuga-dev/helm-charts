# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [opentelemetry-kube-stack-0.6.1] - 2026-03-16

### Added

- Add k8sattributes to cluster receiver and k8s-objects example

### Changed

- Bump version
- Merge pull request #71 from tsuga-dev/feat/otel-cluster-receiver-k8sattributes-and-k8sobjects-example

## [opentelemetry-kube-stack-0.6.0] - 2026-03-13

### Added

- Enhance cluster receiver and daemonset metrics collection
- Add permissions for Kubernetes events collection

### Changed

- Bump chart version to 0.6.0 and update documentation
- Regenerate rendered examples with enhanced configuration
- Make collectk8sobjects optional
- Merge pull request #70 from tsuga-dev/pimpin

## [opentelemetry-kube-stack-0.5.1] - 2026-03-12

### Added

- Add extraLabelMapping and extraAnnotationsMapping to statefulset

### Changed

- Bump version
- Merge pull request #68 from tsuga-dev/feat/statefulset-extra-label-annotation-mapping

## [opentelemetry-kube-stack-0.5.0] - 2026-03-12

### Changed

- Merge branch 'main' into feat/target-allocator-support
- Merge pull request #67 from tsuga-dev/feat/target-allocator-support

## [opentelemetry-kube-stack-0.4.1] - 2026-02-27

### Added

- Add statefulset collector template
- Add TargetAllocator CR template
- Complete targetAllocator and statefulset values
- Fix statefulset values documentation
- Add PrometheusCR RBAC rules for Target Allocator
- Add schema for targetAllocator and statefulset values
- Add target-allocator example

### Changed

- Add statefulset collector-TA link tests
- Bump version
- Merge pull request #66 from tsuga-dev/bugfix/tolerations-schema-type

### Fixed

- Make replicas conditional, document TA coupling
- Guard TargetAllocator serviceAccount on serviceAccount.create
- Tolerations type, add serviceAccount guard test
- Add TA endpoint, POD_NAME, memory_limiter to statefulset collector
- Add EndpointSlices RBAC for TargetAllocator service discovery
- Fix replicas schema type (string → integer)
- Gate EndpointSlices RBAC on targetAllocator.enabled
- Add placeholder scrape_config for TargetAllocator override
- Shorten statefulset CR name to avoid 63-char label limit
- Add net.host.name and cumulativetodelta to statefulset collector
- Fix tolerations type for agent and cluster

## [opentelemetry-kube-stack-0.4.0] - 2026-02-17

### Added

- Add dynamic receiver discovery and multiline logs
- Make clusterName optional with warning
- Document operator and cert-manager requirements

### Changed

- Add auto-instrumentation examples and testing framework
- Merge pull request #44 from tsuga-dev/tests/add-autoinstrumentation-unittests
- Merge pull request #58 from tsuga-dev/feat/dynamic-receiver-discovery-multiline-logs
- Merge pull request #59 from tsuga-dev/feat/optional-cluster-name
- Remove unused otel-crds dependency
- Merge pull request #61 from tsuga-dev/feat/add-resourcedetection-processor
- Bump version
- Merge pull request #62 from tsuga-dev/release/bump-kubstack-0.4.0
- Merge pull request #63 from tsuga-dev/release/bump-kubstack-0.4.0

### Fixed

- Update gitignore and operator condition

## [opentelemetry-kube-stack-0.3.0] - 2026-02-02

### Added

- Add auto-instrumentation support

### Changed

- Merge pull request #42 from tsuga-dev/feat/auto-instrumentation-support

## [opentelemetry-kube-stack-0.2.16] - 2026-02-02

### Added

- Configure batch processor with optimized settings

### Changed

- Merge commit '6ede1ed41f9b4daef4edba0a2907b60abe42b25c'
- Bump version
- Merge pull request #41 from tsuga-dev/feat/configure-batch-processor

## [opentelemetry-kube-stack-0.2.15] - 2026-01-14

### Changed

- Add 'addLogsVolumes' option to agent configuration for log collection in OpenTelemetry stack
- Bump version
- Merge pull request #38 from tsuga-dev/feat-logs-volumes

## [opentelemetry-kube-stack-0.2.14] - 2026-01-12

### Changed

- Enhance OpenTelemetry configuration by adding k8s_observer extension for improved Kubernetes resource observation. Update daemonset and service templates to include new logging receiver and adjust extraExtensions handling.
- Merge pull request #36 from tsuga-dev/fix-service-definition-for-extra-extensions
- Bump version
- Merge pull request #37 from tsuga-dev/fix-custom-config-not-being-taken-in-count

### Fixed

- Fix custom config not being taken in count

## [opentelemetry-kube-stack-0.2.13] - 2026-01-12

### Changed

- Update OpenTelemetry configuration in README, schema, and values files to change 'extraExtensions' from object to array type for both agent and cluster services.
- Merge pull request #34 from tsuga-dev/fix-schema-validation-in-kube-stack
- Bump opentelemetry-kube-stack chart version to 0.2.13
- Merge pull request #35 from tsuga-dev/bump-version-to-0.2.13

## [opentelemetry-kube-stack-0.2.12] - 2026-01-05

### Changed

- Bump chart version to 0.2.12 and remove 'exclude_dimensions' from daemonset configuration
- Merge pull request #29 from tsuga-dev/fix-remove-excusion-dimention

## [opentelemetry-kube-stack-0.2.11] - 2026-01-05

### Changed

- Bump chart version to 0.2.11 and update spanmetrics connector configuration
- Merge pull request #27 from tsuga-dev/bump-version-and-update-daemonset-config

## [opentelemetry-kube-stack-0.2.10] - 2025-12-17

### Changed

- Update OpenTelemetry kube-stack to version 0.2.10 and modify configuration to use NODE_IP for endpoint resolution
- Merge pull request #25 from tsuga-dev/fix-kubeletstats-receiver

## [opentelemetry-kube-stack-0.2.9] - 2025-12-17

### Changed

- Add host filesystem support in daemonset configuration
- Bump version
- Merge pull request #23 from tsuga-dev/fix-Host-Metrics-Receiver

## [opentelemetry-kube-stack-0.2.8] - 2025-12-16

### Changed

- Add conditional log collection configuration in daemonset template
- Bump version
- Merge pull request #21 from tsuga-dev/fix-kube-stack-log-collection

## [opentelemetry-kube-stack-0.2.7] - 2025-12-15

### Changed

- Add Helm ownership annotations to all resources
- Bump version
- Merge pull request #19 from tsuga-dev/fix-helm-ownership-annotations

## [opentelemetry-kube-stack-0.2.6] - 2025-12-12

### Changed

- Fix regex in cluster name validation to allow underscores in addition to hyphens.
- Merge pull request #11 from tsuga-dev/fix-cluster-name-validation
- Add annotations to OpenTelemetry configuration in _config.tpl
- Add OpenTelemetry configuration schema and enhance values.yaml
- Fix templates
- Update examples
- Add extraConnectors configuration to OpenTelemetry schema and values.yaml
- Fix _service.tpl
- Bump versions
- Update Doc
- Merge pull request #14 from tsuga-dev/otel-demo-improvement
- Revert "Otel-demo-improvement"
- Merge pull request #15 from tsuga-dev/revert-14-otel-demo-improvement
- Add OpenTelemetry configuration and CI enhancements
- Merge pull request #17 from tsuga-dev/kube-stack-standerdise

## [opentelemetry-kube-stack-0.2.5] - 2025-10-31

### Changed

- Update OpenTelemetry Kube Stack to v0.2.5
- Add Change Log
- Remove duplicated attributes
- Fix grammar
- Fix indentation in _config.tpl to properly align k8sattributes and labels sections
- Merge pull request #9 from tsuga-dev/update-opentelemetry-stack-v0.2.5

## [opentelemetry-kube-stack-0.2.4] - 2025-10-17

### Changed

- Remove 'k8sattributes' processor from cluster receiver configuration in example YAML files and Helm template.
- Bump version
- Merge pull request #7 from tsuga-dev/fix-config-issue

## [opentelemetry-kube-stack-0.2.3] - 2025-10-17

### Changed

- Add collection settings configuration to deploy script
- Add cluster name configuration to deploy script and Helm templates
- Merge pull request #5 from tsuga-dev/feat-host-metrics
- Update release workflow and increment OpenTelemetry Kube Stack chart version
- Merge pull request #6 from tsuga-dev/Release-0.2.3

## [opentelemetry-kube-stack-0.2.2] - 2025-10-07

### Changed

- Merge remote-tracking branch 'origin/main' into extraConfig
- Bump version
- Merge pull request #4 from tsuga-dev/extraConfig

## [opentelemetry-kube-stack-0.2.1] - 2025-10-06

### Changed

- Enhance OpenTelemetry Kube Stack configuration and examples
- Update Helm chart and README for Tsuga integration
- Merge pull request #3 from tsuga-dev/release-0.2.1

## [opentelemetry-kube-stack-0.2.0] - 2025-10-06

### Changed

- First commit
- Add Makefile for example generation and validation; update Helm chart configurations
- Merge pull request #2 from tsuga-dev/update-secret-management

[opentelemetry-kube-stack-0.6.1]: https://github.com///compare/opentelemetry-kube-stack-0.6.0..opentelemetry-kube-stack-0.6.1
[opentelemetry-kube-stack-0.6.0]: https://github.com///compare/opentelemetry-kube-stack-0.5.1..opentelemetry-kube-stack-0.6.0
[opentelemetry-kube-stack-0.5.1]: https://github.com///compare/opentelemetry-kube-stack-0.5.0..opentelemetry-kube-stack-0.5.1
[opentelemetry-kube-stack-0.5.0]: https://github.com///compare/opentelemetry-kube-stack-0.4.1..opentelemetry-kube-stack-0.5.0
[opentelemetry-kube-stack-0.4.1]: https://github.com///compare/opentelemetry-kube-stack-0.4.0..opentelemetry-kube-stack-0.4.1
[opentelemetry-kube-stack-0.4.0]: https://github.com///compare/opentelemetry-kube-stack-0.3.0..opentelemetry-kube-stack-0.4.0
[opentelemetry-kube-stack-0.3.0]: https://github.com///compare/opentelemetry-kube-stack-0.2.16..opentelemetry-kube-stack-0.3.0
[opentelemetry-kube-stack-0.2.16]: https://github.com///compare/opentelemetry-kube-stack-0.2.15..opentelemetry-kube-stack-0.2.16
[opentelemetry-kube-stack-0.2.15]: https://github.com///compare/opentelemetry-kube-stack-0.2.14..opentelemetry-kube-stack-0.2.15
[opentelemetry-kube-stack-0.2.14]: https://github.com///compare/opentelemetry-kube-stack-0.2.13..opentelemetry-kube-stack-0.2.14
[opentelemetry-kube-stack-0.2.13]: https://github.com///compare/opentelemetry-kube-stack-0.2.12..opentelemetry-kube-stack-0.2.13
[opentelemetry-kube-stack-0.2.12]: https://github.com///compare/opentelemetry-kube-stack-0.2.11..opentelemetry-kube-stack-0.2.12
[opentelemetry-kube-stack-0.2.11]: https://github.com///compare/opentelemetry-kube-stack-0.2.10..opentelemetry-kube-stack-0.2.11
[opentelemetry-kube-stack-0.2.10]: https://github.com///compare/opentelemetry-kube-stack-0.2.9..opentelemetry-kube-stack-0.2.10
[opentelemetry-kube-stack-0.2.9]: https://github.com///compare/opentelemetry-kube-stack-0.2.8..opentelemetry-kube-stack-0.2.9
[opentelemetry-kube-stack-0.2.8]: https://github.com///compare/opentelemetry-kube-stack-0.2.7..opentelemetry-kube-stack-0.2.8
[opentelemetry-kube-stack-0.2.7]: https://github.com///compare/opentelemetry-kube-stack-0.2.6..opentelemetry-kube-stack-0.2.7
[opentelemetry-kube-stack-0.2.6]: https://github.com///compare/opentelemetry-kube-stack-0.2.5..opentelemetry-kube-stack-0.2.6
[opentelemetry-kube-stack-0.2.5]: https://github.com///compare/opentelemetry-kube-stack-0.2.4..opentelemetry-kube-stack-0.2.5
[opentelemetry-kube-stack-0.2.4]: https://github.com///compare/opentelemetry-kube-stack-0.2.3..opentelemetry-kube-stack-0.2.4
[opentelemetry-kube-stack-0.2.3]: https://github.com///compare/opentelemetry-kube-stack-0.2.2..opentelemetry-kube-stack-0.2.3
[opentelemetry-kube-stack-0.2.2]: https://github.com///compare/opentelemetry-kube-stack-0.2.1..opentelemetry-kube-stack-0.2.2
[opentelemetry-kube-stack-0.2.1]: https://github.com///compare/opentelemetry-kube-stack-0.2.0..opentelemetry-kube-stack-0.2.1
[opentelemetry-kube-stack-0.2.0]: https://github.com///tree/opentelemetry-kube-stack-0.2.0

