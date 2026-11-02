# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.1] - 2026-11-02

### Changed

- Collectors default to OTel Collector 0.164.0, from 0.161.0: the agent, scraper and PostgreSQL collectors on the contrib distribution, the gateway on the k8s distribution and the profiler on the eBPF profiler distribution. If you set `spec.image` or `profiling.image`, test the new release before moving to it.
- The PostgreSQL collector config uses the `sql_query` receiver name instead of its deprecated `sqlquery` alias (renamed upstream in 0.159.0). Emitted metrics and logs are unchanged.
