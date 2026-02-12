# opentelemetry-demo

![Version: 0.6.3](https://img.shields.io/badge/Version-0.6.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.40.0](https://img.shields.io/badge/AppVersion-0.40.0-informational?style=flat-square)

A Helm chart for Tsuga Observability Demo

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://open-telemetry.github.io/opentelemetry-helm-charts | opentelemetry-demo(opentelemetry-demo) | 0.40.0 |
| https://tsuga-dev.github.io/helm-charts | opentelemetry-kube-stack | 0.2.15 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| opentelemetry-demo.components.accounting.env[0].name | string | `"OTEL_DOTNET_AUTO_METRICS_ADDITIONAL_SOURCES"` |  |
| opentelemetry-demo.components.accounting.env[0].value | string | `"System.Runtime,Microsoft.AspNetCore.Hosting"` |  |
| opentelemetry-demo.components.accounting.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.ad.env[0].name | string | `"OTEL_INSTRUMENTATION_RUNTIME_TELEMETRY_ENABLED"` |  |
| opentelemetry-demo.components.ad.env[0].value | string | `"true"` |  |
| opentelemetry-demo.components.ad.env[1].name | string | `"OTEL_INSTRUMENTATION_RUNTIME_TELEMETRY_EMIT_EXPERIMENTAL_TELEMETRY"` |  |
| opentelemetry-demo.components.ad.env[1].value | string | `"true"` |  |
| opentelemetry-demo.components.ad.env[2].name | string | `"OTEL_INSTRUMENTATION_JMX_ENABLED"` |  |
| opentelemetry-demo.components.ad.env[2].value | string | `"true"` |  |
| opentelemetry-demo.components.ad.env[3].name | string | `"OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_CLIENT_REQUEST"` |  |
| opentelemetry-demo.components.ad.env[3].value | string | `"content-type,user-agent"` |  |
| opentelemetry-demo.components.ad.env[4].name | string | `"OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST"` |  |
| opentelemetry-demo.components.ad.env[4].value | string | `"content-type,user-agent,accept"` |  |
| opentelemetry-demo.components.ad.env[5].name | string | `"OTEL_INSTRUMENTATION_GRPC_ENABLED"` |  |
| opentelemetry-demo.components.ad.env[5].value | string | `"true"` |  |
| opentelemetry-demo.components.ad.env[6].name | string | `"OTEL_INSTRUMENTATION_LOG4J_APPENDER_ENABLED"` |  |
| opentelemetry-demo.components.ad.env[6].value | string | `"true"` |  |
| opentelemetry-demo.components.ad.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.cart.podAnnotations."resource.opentelemetry.io/team" | string | `"app"` |  |
| opentelemetry-demo.components.checkout.podAnnotations."resource.opentelemetry.io/team" | string | `"app"` |  |
| opentelemetry-demo.components.currency.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.email.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.flagd.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.fraud-detection.env[0].name | string | `"OTEL_INSTRUMENTATION_RUNTIME_TELEMETRY_ENABLED"` |  |
| opentelemetry-demo.components.fraud-detection.env[0].value | string | `"true"` |  |
| opentelemetry-demo.components.fraud-detection.env[1].name | string | `"OTEL_INSTRUMENTATION_RUNTIME_TELEMETRY_EMIT_EXPERIMENTAL_TELEMETRY"` |  |
| opentelemetry-demo.components.fraud-detection.env[1].value | string | `"true"` |  |
| opentelemetry-demo.components.fraud-detection.env[2].name | string | `"OTEL_INSTRUMENTATION_JMX_ENABLED"` |  |
| opentelemetry-demo.components.fraud-detection.env[2].value | string | `"true"` |  |
| opentelemetry-demo.components.fraud-detection.env[3].name | string | `"OTEL_INSTRUMENTATION_KAFKA_ENABLED"` |  |
| opentelemetry-demo.components.fraud-detection.env[3].value | string | `"true"` |  |
| opentelemetry-demo.components.fraud-detection.env[4].name | string | `"OTEL_INSTRUMENTATION_KAFKA_METRIC_REPORTER_ENABLED"` |  |
| opentelemetry-demo.components.fraud-detection.env[4].value | string | `"true"` |  |
| opentelemetry-demo.components.fraud-detection.env[5].name | string | `"OTEL_INSTRUMENTATION_LOG4J_APPENDER_ENABLED"` |  |
| opentelemetry-demo.components.fraud-detection.env[5].value | string | `"true"` |  |
| opentelemetry-demo.components.fraud-detection.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.frontend-proxy.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.frontend.podAnnotations."resource.opentelemetry.io/team" | string | `"app"` |  |
| opentelemetry-demo.components.image-provider.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.kafka.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.load-generator.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.payment.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.postgresql.command[0] | string | `"docker-entrypoint.sh"` |  |
| opentelemetry-demo.components.postgresql.command[1] | string | `"-c"` |  |
| opentelemetry-demo.components.postgresql.command[2] | string | `"log_destination=stderr"` |  |
| opentelemetry-demo.components.postgresql.command[3] | string | `"-c"` |  |
| opentelemetry-demo.components.postgresql.command[4] | string | `"log_min_duration_statement=0"` |  |
| opentelemetry-demo.components.postgresql.command[5] | string | `"-c"` |  |
| opentelemetry-demo.components.postgresql.command[6] | string | `"log_line_prefix=%m [%p] %u@%d %"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."io.opentelemetry.discovery.logs/config" | string | `"include_file_path: true\noperators:\n  - type: container\n    id: container-parser\n\n  # Drop Postgres DETAIL logs\n  - type: filter\n    id: drop-postgres-detail\n    expr: 'body matches \"^\\\\d{4}-\\\\d{2}-\\\\d{2} .*\\\\bDETAIL:\"'\n\n  # Recombine Postgres multi-line statements (SQL blocks, wrapped lines, etc.)\n  - type: recombine\n    id: postgres-multiline\n    combine_field: body\n    is_first_entry: body matches \"^\\\\d{4}-\\\\d{2}-\\\\d{2} \"\n    source_identifier: attributes[\"log.file.path\"]\n    force_flush_period: 2s\n    max_log_size: 2MiB\n    preserve_leading_whitespaces: true\n"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."io.opentelemetry.discovery.logs/enabled" | string | `"true"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."resource.opentelemetry.io/service.name" | string | `"postgresql"` |  |
| opentelemetry-demo.components.postgresql.podAnnotations."resource.opentelemetry.io/team" | string | `"platform"` |  |
| opentelemetry-demo.components.product-catalog.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.product-reviews.imageOverride.repository | string | `"014498635196.dkr.ecr.eu-central-1.amazonaws.com/tsuga-dev/otel-demo"` |  |
| opentelemetry-demo.components.product-reviews.imageOverride.tag | string | `"2.2.0-product-reviews"` |  |
| opentelemetry-demo.components.product-reviews.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.quote.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.recommendation.env[0].name | string | `"OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED"` |  |
| opentelemetry-demo.components.recommendation.env[0].value | string | `"true"` |  |
| opentelemetry-demo.components.recommendation.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
| opentelemetry-demo.components.shipping.podAnnotations."resource.opentelemetry.io/team" | string | `"services"` |  |
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
| opentelemetry-kube-stack.agent.config.extraExtensions.k8s_observer.observe_ingresses | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraExtensions.k8s_observer.observe_nodes | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraExtensions.k8s_observer.observe_services | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.brokers[0] | string | `"kafka:9092"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.collection_interval | string | `"10s"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.group_match | string | `".*"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.metrics."kafka.consumer_group.lag".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.metrics."kafka.consumer_group.offset".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.metrics."kafka.partition.current_offset".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.metrics."kafka.partition.oldest_offset".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.metrics."kafka.partition.replicas".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.metrics."kafka.partition.replicas_in_sync".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.protocol_version | string | `"2.0.0"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.scrapers[0] | string | `"brokers"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.scrapers[1] | string | `"topics"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.scrapers[2] | string | `"consumers"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.kafkametrics.topic_match | string | `"^[^_].*$"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.nginx.collection_interval | string | `"10s"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.nginx.endpoint | string | `"http://image-provider.default:8081/status"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.collection_interval | string | `"10s"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.endpoint | string | `"postgresql.default:5432"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.backends".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.blks_hit".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.blks_read".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.commits".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.connection.max".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.database.locks".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.deadlocks".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.index.scans".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.index.size".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.replication.data_delay".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.rollbacks".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.sequential_scans".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.table.count".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.table.size".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.table.vacuum.count".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.temp_files".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.tup_deleted".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.tup_fetched".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.tup_inserted".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.tup_returned".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.metrics."postgresql.tup_updated".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.password | string | `"otel"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.tls.insecure | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.postgresql.username | string | `"root"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.prometheus.config.scrape_configs[0].job_name | string | `"envoy"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.prometheus.config.scrape_configs[0].metrics_path | string | `"/stats/prometheus"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.prometheus.config.scrape_configs[0].scrape_interval | string | `"30s"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.prometheus.config.scrape_configs[0].static_configs[0].targets[0] | string | `"frontend-proxy:10000"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.receiver_creator/logs.discovery.enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.receiver_creator/logs.watch_observers[0] | string | `"k8s_observer"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.collection_interval | string | `"10s"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.endpoint | string | `"valkey-cart.default:6379"` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.clients.blocked".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.clients.connected".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.cmd.calls".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.cmd.latency".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.cpu.time".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.keys.evicted".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.keys.expired".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.maxmemory".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.memory.lua".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.memory.peak".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.memory.rss".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.memory.used".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.net.input".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.net.output".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.metrics."redis.replication.offset".enabled | bool | `true` |  |
| opentelemetry-kube-stack.agent.config.extraReceivers.redis.username | string | `"valkey"` |  |
| opentelemetry-kube-stack.agent.config.service.extraExtensions[0] | string | `"k8s_observer"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.logs.extraReceivers[0] | string | `"receiver_creator/logs"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.metrics.extraReceivers[0] | string | `"postgresql"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.metrics.extraReceivers[1] | string | `"redis"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.metrics.extraReceivers[2] | string | `"nginx"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.metrics.extraReceivers[3] | string | `"kafkametrics"` |  |
| opentelemetry-kube-stack.agent.config.service.pipelines.metrics.extraReceivers[4] | string | `"prometheus"` |  |
| opentelemetry-kube-stack.agent.image | string | `"ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib"` |  |
| opentelemetry-kube-stack.enabled | bool | `true` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
