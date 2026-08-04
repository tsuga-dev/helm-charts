-- Microsoft SQL Server monitoring setup for OpenTelemetry
-- Run as a login with sysadmin (or CREATE LOGIN + GRANT OPTION on the grants below).
-- Safe to re-run (all statements are idempotent).
--
-- The password below is a placeholder: the setup Job rewrites it with the
-- generated value from the monitor secret immediately after running this script,
-- so the literal never survives setup. It still has to satisfy the server's
-- password policy for CREATE LOGIN to succeed.

-- ---------------------------------------------------------------------------
-- 1. Monitoring login
-- ---------------------------------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'otel_monitor')
    CREATE LOGIN otel_monitor WITH PASSWORD = 'Pl4ceholder!Rotated', CHECK_POLICY = ON;
GO

-- Permission to read the server-state DMVs the receiver scrapes.
--
-- SQL Server 2022 (major version 16) introduced VIEW SERVER PERFORMANCE STATE as
-- the granular replacement for VIEW SERVER STATE. The new name does not exist on
-- earlier versions, so the grant is selected from the server's major version.
DECLARE @major int = CONVERT(int, SERVERPROPERTY('ProductMajorVersion'));
IF @major >= 16
    EXEC('GRANT VIEW SERVER PERFORMANCE STATE TO otel_monitor');
ELSE
    EXEC('GRANT VIEW SERVER STATE TO otel_monitor');
GO

-- Required by the receiver to enumerate databases.
GRANT VIEW ANY DATABASE TO otel_monitor;
GO

-- Required only for the per-index physical stats metrics (sqlserver.index.*):
-- the receiver enters each user database to read them.
GRANT CONNECT ANY DATABASE TO otel_monitor;
GRANT VIEW ANY DEFINITION TO otel_monitor;
GO

-- ---------------------------------------------------------------------------
-- 2. Monitoring database
-- ---------------------------------------------------------------------------

IF DB_ID('otel') IS NULL CREATE DATABASE otel;
GO

USE otel;
GO

-- ---------------------------------------------------------------------------
-- 3. Monitoring views
--
-- Attribute columns use OTel semconv names where defined:
--   db.namespace     → database name  (stable semconv)
--   db.query.text    → statement text (stable semconv)
--   db.query.hash    → query_hash     (experimental)
-- ---------------------------------------------------------------------------

-- Top queries by total elapsed time, from the plan cache.
--
-- Three details in this query the metric depends on:
--   * The database is resolved from sys.dm_exec_plan_attributes rather than from
--     sys.dm_exec_sql_text, which reports a NULL dbid for ad-hoc batches and
--     would leave db.namespace empty for them.
--   * System databases are excluded. The collector's own DMV queries execute in
--     the master context and would otherwise occupy the top-N.
--   * last_execution_time bounds the window to recent activity.
--     sys.dm_exec_query_stats accumulates for as long as a plan stays cached, so
--     an unbounded query reports the highest all-time totals on every scrape and
--     stops reflecting current load. 300s covers the 60s collection interval.
CREATE OR ALTER VIEW dbo.sqlserver_top_queries AS
SELECT TOP 50
    DB_NAME(CONVERT(int, pa.value))          AS [db.namespace],
    CONVERT(varchar(64), qs.query_hash, 1)   AS [db.query.hash],
    LEFT(COALESCE(t.text, ''), 1024)         AS [db.query.text],
    qs.execution_count                       AS calls,
    qs.total_worker_time  / 1000.0           AS total_cpu_time_ms,
    qs.total_elapsed_time / 1000.0           AS total_elapsed_time_ms,
    qs.total_logical_reads                   AS logical_reads,
    qs.total_physical_reads                  AS physical_reads,
    qs.total_logical_writes                  AS logical_writes,
    qs.total_rows                            AS rows_returned
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa
WHERE pa.attribute = 'dbid'
  AND DB_NAME(CONVERT(int, pa.value)) IS NOT NULL
  AND DB_NAME(CONVERT(int, pa.value)) NOT IN ('master', 'tempdb', 'model', 'msdb', 'otel')
  AND qs.last_execution_time > DATEADD(second, -300, GETDATE())
ORDER BY qs.total_elapsed_time DESC;
GO

-- Sessions currently blocked on another session, with the blocking chain.
CREATE OR ALTER VIEW dbo.sqlserver_blocking AS
SELECT
    COALESCE(DB_NAME(r.database_id), '')     AS [db.namespace],
    COALESCE(r.wait_type, '')                AS [db.mssql.wait.type],
    COUNT(*)                                 AS blocked_session_count,
    COALESCE(MAX(r.wait_time), 0) / 1000.0   AS max_wait_time_ms
FROM sys.dm_exec_requests r
WHERE r.blocking_session_id <> 0
GROUP BY DB_NAME(r.database_id), r.wait_type;
GO

-- ---------------------------------------------------------------------------
-- 4. Grant the monitor login read access to the views
-- ---------------------------------------------------------------------------

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'otel_monitor')
    CREATE USER otel_monitor FOR LOGIN otel_monitor;
GO

GRANT SELECT ON SCHEMA::dbo TO otel_monitor;
GO
