// MongoDB monitoring setup for OpenTelemetry
// Run with mongosh as a user holding userAdmin (or root) on the admin database.
// Safe to re-run (idempotent).
//
// This script provisions the least-privilege monitor user that the receiver
// authenticates as. No helper collections or views are needed: the receiver
// reads the serverStatus, dbStats, and index stats commands directly.
//
// The password is read from OTEL_MONITOR_PASSWORD in the environment, so it is
// not written into this file or into the Job's command line.

const monitorPassword = process.env.OTEL_MONITOR_PASSWORD;
if (!monitorPassword) {
  throw new Error("OTEL_MONITOR_PASSWORD is not set; refusing to create a user without a password");
}

const admin = db.getSiblingDB("admin");

// clusterMonitor is the built-in role MongoDB documents for a least-privilege
// monitoring user, and the role the receiver requires to collect metrics.
const roles = [{ role: "clusterMonitor", db: "admin" }];

const existing = admin.getUser("otel_monitor");
if (existing === null) {
  admin.createUser({ user: "otel_monitor", pwd: monitorPassword, roles: roles });
  print("created user otel_monitor");
} else {
  // updateUser sets the password in place and re-asserts the roles. This makes a
  // re-run after the monitor secret changes converge on the new password rather
  // than fail because the user already exists.
  admin.updateUser("otel_monitor", { pwd: monitorPassword, roles: roles });
  print("updated user otel_monitor");
}
