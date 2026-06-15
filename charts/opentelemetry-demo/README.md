# opentelemetry-demo

![Version: 0.9.6](https://img.shields.io/badge/Version-0.9.6-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.40.0](https://img.shields.io/badge/AppVersion-0.40.0-informational?style=flat-square)

A Helm chart for Tsuga Observability Demo

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://open-telemetry.github.io/opentelemetry-helm-charts | opentelemetry-demo(opentelemetry-demo) | 0.40.0 |
| https://tsuga-dev.github.io/helm-charts | dbm(opentelemetry-database-monitoring) | 0.1.1 |
| https://tsuga-dev.github.io/helm-charts | opentelemetry-kube-stack | 0.7.2 |
| https://tsuga-dev.github.io/helm-charts | tsuga-spicy-gremlin | 0.1.2 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| dbm.enabled | bool | `true` |  |
| dbm.postgres.databases[0].host | string | `"postgresql"` |  |
| dbm.postgres.databases[0].name | string | `"postgresql"` |  |
| dbm.postgres.databases[0].namespace | string | `"demo"` |  |
| dbm.postgres.databases[0].port | int | `5432` |  |
| dbm.postgres.databases[0].pwd | string | `"otel"` |  |
| dbm.postgres.databases[0].sidecar-name | string | `"postgres-dbm-sidecar"` |  |
| dbm.postgres.databases[0].user | string | `"root"` |  |
| dbm.postgres.enabled | bool | `true` |  |
| dbm.postgres.image | string | `"ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib"` |  |
| opentelemetry-demo.components.accounting.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.accounting.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.accounting.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.ad.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.ad.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.ad.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.cart.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.cart.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.cart.podAnnotations."resource.opentelemetry.io/team" | string | `"app"` |  |
| opentelemetry-demo.components.checkout.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.checkout.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.checkout.podAnnotations."resource.opentelemetry.io/team" | string | `"app"` |  |
| opentelemetry-demo.components.currency.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.currency.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.currency.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.email.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.email.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.email.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.flagd.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.flagd.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.flagd.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.fraud-detection.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.fraud-detection.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.fraud-detection.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.frontend-proxy.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.frontend-proxy.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.frontend-proxy.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.frontend.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n\n  # Recombine Next.js multi-line errors (stack traces)\n  - type: recombine\n    id: nextjs-multiline\n    combine_field: body\n    is_first_entry: body matches \"^Error:\"\n    source_identifier: attributes[\"log.file.path\"]\n    force_flush_period: 2s\n    max_log_size: 2MiB\n    preserve_leading_whitespaces: true\n"` |  |
| opentelemetry-demo.components.frontend.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.frontend.podAnnotations."resource.opentelemetry.io/service.name" | string | `"frontend"` |  |
| opentelemetry-demo.components.frontend.podAnnotations."resource.opentelemetry.io/team" | string | `"app"` |  |
| opentelemetry-demo.components.image-provider.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n\n  # Recombine Envoy/nginx multi-line logs (continuation lines without timestamp)\n  - type: recombine\n    id: envoy-multiline\n    combine_field: body\n    is_first_entry: body matches \"^\\\\[\\\\d{4}-\\\\d{2}-\\\\d{2} \\\\d{2}:\\\\d{2}:\\\\d{2}\\\\.\\\\d{3}\\\\]\"\n    source_identifier: attributes[\"log.file.path\"]\n    force_flush_period: 2s\n    max_log_size: 2MiB\n    preserve_leading_whitespaces: true\n"` |  |
| opentelemetry-demo.components.image-provider.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.image-provider.podAnnotations."io.opentelemetry.discovery.metrics.8081/config" | string | `"endpoint: \"http://`endpoint`/status\"\ncollection_interval: 10s\n"` |  |
| opentelemetry-demo.components.image-provider.podAnnotations."io.opentelemetry.discovery.metrics.8081/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.image-provider.podAnnotations."io.opentelemetry.discovery.metrics.8081/scraper" | string | `"nginx"` |  |
| opentelemetry-demo.components.image-provider.podAnnotations."resource.opentelemetry.io/service.name" | string | `"image-provider"` |  |
| opentelemetry-demo.components.image-provider.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.kafka.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.kafka.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.kafka.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.load-generator.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.load-generator.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.load-generator.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.payment.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.payment.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.payment.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.postgresql.additionalVolumeMounts[0].mountPath | string | `"/var/lib/postgres/data"` |  |
| opentelemetry-demo.components.postgresql.additionalVolumeMounts[0].name | string | `"db-data"` |  |
| opentelemetry-demo.components.postgresql.additionalVolumes[0].name | string | `"db-data"` |  |
| opentelemetry-demo.components.postgresql.additionalVolumes[0].persistentVolumeClaim.claimName | string | `"db-persistent-volume-claim"` |  |
| opentelemetry-demo.components.postgresql.command[0] | string | `"docker-entrypoint.sh"` |  |
| opentelemetry-demo.components.postgresql.command[1] | string | `"-c"` |  |
| opentelemetry-demo.components.postgresql.command[2] | string | `"log_destination=stderr"` |  |
| opentelemetry-demo.components.postgresql.command[3] | string | `"-c"` |  |
| opentelemetry-demo.components.postgresql.command[4] | string | `"log_min_duration_statement=0"` |  |
| opentelemetry-demo.components.postgresql.command[5] | string | `"-c"` |  |
| opentelemetry-demo.components.postgresql.command[6] | string | `"log_line_prefix=%m [%p] %u@%d %"` |  |
| opentelemetry-demo.components.postgresql.command[7] | string | `"-c"` |  |
| opentelemetry-demo.components.postgresql.command[8] | string | `"shared_preload_libraries=pg_stat_statements"` |  |
| opentelemetry-demo.components.postgresql.mountedConfigMaps[0].existingConfigMap | string | `"postgresql-init"` |  |
| opentelemetry-demo.components.postgresql.mountedConfigMaps[0].mountPath | string | `"/docker-entrypoint-initdb.d/init.sql"` |  |
| opentelemetry-demo.components.postgresql.mountedConfigMaps[0].name | string | `"postgresql-init"` |  |
| opentelemetry-demo.components.postgresql.mountedConfigMaps[0].subPath | string | `"init.sql"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n\n  # Drop Postgres DETAIL logs\n  - type: filter\n    id: drop-postgres-detail\n    expr: 'body matches \"^\\\\d{4}-\\\\d{2}-\\\\d{2} .*\\\\bDETAIL:\"'\n\n  # Recombine Postgres multi-line statements (SQL blocks, wrapped lines, etc.)\n  - type: recombine\n    id: postgres-multiline\n    combine_field: body\n    is_first_entry: body matches \"^\\\\d{4}-\\\\d{2}-\\\\d{2} \"\n    source_identifier: attributes[\"log.file.path\"]\n    force_flush_period: 2s\n    max_log_size: 2MiB\n    preserve_leading_whitespaces: true\n"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."resource.opentelemetry.io/service.name" | string | `"postgresql"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."sidecar.opentelemetry.io/inject" | string | `"postgres-dbm-sidecar"` |  |
| opentelemetry-demo.components.product-catalog.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.product-catalog.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.product-catalog.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.product-reviews.imageOverride.repository | string | `"014498635196.dkr.ecr.eu-central-1.amazonaws.com/tsuga-dev/otel-demo"` |  |
| opentelemetry-demo.components.product-reviews.imageOverride.tag | string | `"2.2.0-product-reviews"` |  |
| opentelemetry-demo.components.product-reviews.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.product-reviews.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.product-reviews.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.quote.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.quote.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.quote.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.recommendation.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.recommendation.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.recommendation.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.shipping.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| opentelemetry-demo.components.shipping.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.shipping.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.valkey-cart.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n\n  # Recombine Valkey/Redis multi-line logs (entries start with process:role timestamp pattern)\n  - type: recombine\n    id: valkey-multiline\n    combine_field: body\n    is_first_entry: body matches \"^\\\\d+:[A-Z] \\\\d{2} [A-Z][a-z]{2} \\\\d{4} \\\\d{2}:\\\\d{2}:\\\\d{2}\\\\.\\\\d{3}\"\n    source_identifier: attributes[\"log.file.path\"]\n    force_flush_period: 2s\n    max_log_size: 2MiB\n    preserve_leading_whitespaces: true\n"` |  |
| opentelemetry-demo.components.valkey-cart.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.valkey-cart.podAnnotations."io.opentelemetry.discovery.metrics.6379/config" | string | `"collection_interval: 10s\nusername: valkey\n"` |  |
| opentelemetry-demo.components.valkey-cart.podAnnotations."io.opentelemetry.discovery.metrics.6379/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.valkey-cart.podAnnotations."io.opentelemetry.discovery.metrics.6379/scraper" | string | `"redis"` |  |
| opentelemetry-demo.components.valkey-cart.podAnnotations."resource.opentelemetry.io/service.name" | string | `"valkey-cart"` |  |
| opentelemetry-demo.components.valkey-cart.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.default.envOverrides[0].name | string | `"OTEL_COLLECTOR_NAME"` |  |
| opentelemetry-demo.default.envOverrides[0].valueFrom.fieldRef.apiVersion | string | `"v1"` |  |
| opentelemetry-demo.default.envOverrides[0].valueFrom.fieldRef.fieldPath | string | `"status.hostIP"` |  |
| opentelemetry-demo.enabled | bool | `true` |  |
| opentelemetry-demo.grafana.enabled | bool | `false` |  |
| opentelemetry-demo.jaeger.enabled | bool | `false` |  |
| opentelemetry-demo.opensearch.enabled | bool | `false` |  |
| opentelemetry-demo.opentelemetry-collector.enabled | bool | `false` |  |
| opentelemetry-demo.prometheus.enabled | bool | `false` |  |
| opentelemetry-kube-stack.agent.addLogsVolumes | bool | `true` |  |
| opentelemetry-kube-stack.agent.collectLogs | bool | `false` |  |
| opentelemetry-kube-stack.agent.collectNetwork | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraExtensions.k8s_observer.observe_ingresses | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraExtensions.k8s_observer.observe_nodes | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraExtensions.k8s_observer.observe_services | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraProcessors.resource_detection.detectors[0] | string | `"env"` |  |
| opentelemetry-kube-stack.agent.config.extraProcessors.resource_detection.detectors[1] | string | `"eks"` |  |
| opentelemetry-kube-stack.agent.config.extraProcessors.resource_detection.override | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraProcessors.resource_detection.timeout | string | `"15s"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.receiver_creator/logs.discovery.enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.receiver_creator/logs.watch_observers[0] | string | `"k8s_observer"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.receiver_creator/metrics.discovery.enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.receiver_creator/metrics.watch_observers[0] | string | `"k8s_observer"` |  |
| opentelemetry-kube-stack.agent.config.service.extraExtensions[0] | string | `"k8s_observer"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.logs.extraProcessors[0] | string | `"resource_detection"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.logs.extraReceivers[0] | string | `"receiver_creator/logs"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.metrics.extraProcessors[0] | string | `"resource_detection"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.metrics.extraReceivers[0] | string | `"receiver_creator/metrics"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.traces.extraProcessors[0] | string | `"resource_detection"` |  |
| opentelemetry-kube-stack.agent.image | string | `"ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib"` |  |
| opentelemetry-kube-stack.cluster.config.extraProcessors.resource_detection.detectors[0] | string | `"env"` |  |
| opentelemetry-kube-stack.cluster.config.extraProcessors.resource_detection.detectors[1] | string | `"eks"` |  |
| opentelemetry-kube-stack.cluster.config.extraProcessors.resource_detection.override | bool | `true` |  |
| opentelemetry-kube-stack.cluster.config.extraProcessors.resource_detection.timeout | string | `"15s"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.auth_type | string | `"serviceAccount"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.include_initial_state | bool | `true` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[0].group | string | `""` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[0].mode | string | `"watch"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[0].name | string | `"pods"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[1].group | string | `""` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[1].mode | string | `"watch"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[1].name | string | `"events"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[2].group | string | `"apps"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[2].mode | string | `"watch"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[2].name | string | `"deployments"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[3].group | string | `""` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[3].mode | string | `"watch"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[3].name | string | `"nodes"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[4].group | string | `"apps"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[4].mode | string | `"watch"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[4].name | string | `"replicasets"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[5].group | string | `"apps"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[5].mode | string | `"watch"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[5].name | string | `"daemonsets"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[6].group | string | `"apps"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[6].mode | string | `"watch"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8_sobjects.objects[6].name | string | `"statefulsets"` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8s_cluster.metrics."k8s.container.status.reason".enabled | bool | `true` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8s_cluster.metrics."k8s.container.status.state".enabled | bool | `true` |  |
| opentelemetry-kube-stack.cluster.config.extraReceivers.k8s_cluster.metrics."k8s.pod.status_reason".enabled | bool | `true` |  |
| opentelemetry-kube-stack.cluster.config.service.pipelines.logs.extraProcessors[0] | string | `"resource_detection"` |  |
| opentelemetry-kube-stack.cluster.config.service.pipelines.logs.extraReceivers[0] | string | `"k8s_objects"` |  |
| opentelemetry-kube-stack.cluster.config.service.pipelines.metrics.extraProcessors[0] | string | `"resource_detection"` |  |
| opentelemetry-kube-stack.enabled | bool | `true` |  |
| tsuga-spicy-gremlin.enabled | bool | `true` |  |
| tsuga-spicy-gremlin.env.maxIntervalSec | int | `600` |  |
| tsuga-spicy-gremlin.env.minIntervalSec | int | `120` |  |
| tsuga-spicy-gremlin.extraEnv[0].name | string | `"OTEL_EXPORTER_OTLP_PROTOCOL"` |  |
| tsuga-spicy-gremlin.extraEnv[0].value | string | `"http/protobuf"` |  |
| tsuga-spicy-gremlin.extraEnv[10].name | string | `"OTEL_TRACES_SAMPLER_ARG"` |  |
| tsuga-spicy-gremlin.extraEnv[10].value | string | `"1.0"` |  |
| tsuga-spicy-gremlin.extraEnv[11].name | string | `"OTEL_METRIC_EXPORT_INTERVAL"` |  |
| tsuga-spicy-gremlin.extraEnv[11].value | string | `"60000"` |  |
| tsuga-spicy-gremlin.extraEnv[1].name | string | `"OTEL_COLLECTOR_NAME"` |  |
| tsuga-spicy-gremlin.extraEnv[1].valueFrom.fieldRef.apiVersion | string | `"v1"` |  |
| tsuga-spicy-gremlin.extraEnv[1].valueFrom.fieldRef.fieldPath | string | `"status.hostIP"` |  |
| tsuga-spicy-gremlin.extraEnv[2].name | string | `"OTEL_TRACES_EXPORTER"` |  |
| tsuga-spicy-gremlin.extraEnv[2].value | string | `"otlp"` |  |
| tsuga-spicy-gremlin.extraEnv[3].name | string | `"OTEL_METRICS_EXPORTER"` |  |
| tsuga-spicy-gremlin.extraEnv[3].value | string | `"otlp"` |  |
| tsuga-spicy-gremlin.extraEnv[4].name | string | `"OTEL_LOGS_EXPORTER"` |  |
| tsuga-spicy-gremlin.extraEnv[4].value | string | `"none"` |  |
| tsuga-spicy-gremlin.extraEnv[5].name | string | `"OTEL_SERVICE_NAME"` |  |
| tsuga-spicy-gremlin.extraEnv[5].value | string | `"spicy-gremlin"` |  |
| tsuga-spicy-gremlin.extraEnv[6].name | string | `"OTEL_SERVICE_VERSION"` |  |
| tsuga-spicy-gremlin.extraEnv[6].value | string | `"0.1.3"` |  |
| tsuga-spicy-gremlin.extraEnv[7].name | string | `"POD_NAMESPACE"` |  |
| tsuga-spicy-gremlin.extraEnv[7].valueFrom.fieldRef.apiVersion | string | `"v1"` |  |
| tsuga-spicy-gremlin.extraEnv[7].valueFrom.fieldRef.fieldPath | string | `"metadata.namespace"` |  |
| tsuga-spicy-gremlin.extraEnv[8].name | string | `"OTEL_RESOURCE_ATTRIBUTES"` |  |
| tsuga-spicy-gremlin.extraEnv[8].value | string | `"service.name=$(OTEL_SERVICE_NAME),service.version=$(OTEL_SERVICE_VERSION),service.namespace=$(POD_NAMESPACE)"` |  |
| tsuga-spicy-gremlin.extraEnv[9].name | string | `"OTEL_TRACES_SAMPLER"` |  |
| tsuga-spicy-gremlin.extraEnv[9].value | string | `"parentbased_traceidratio"` |  |
| tsuga-spicy-gremlin.image.tag | string | `"0.1.3"` |  |
| tsuga-spicy-gremlin.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n"` |  |
| tsuga-spicy-gremlin.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| tsuga-spicy-gremlin.podAnnotations."resource.opentelemetry.io/service.name" | string | `"spicy-gremlin"` |  |
| tsuga-spicy-gremlin.podAnnotations."resource.opentelemetry.io/service.version" | string | `"0.1.3"` |  |
| tsuga-spicy-gremlin.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
