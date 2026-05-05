-- LibreNMS read-only NOC dashboard seed.
--
-- Run on one LibreNMS node with database access:
--   mysql librenms < docs/read-only-monitoring-dashboard.sql
--
-- The dashboard is owned by the user named below and shared as read-only.
-- Change @dashboard_owner if your read-only/global-read user should own it.
SET @dashboard_owner := 'admin';
SET @dashboard_name := 'Read-Only Monitoring Dashboard';
SET @owner_id := (
  SELECT user_id
  FROM users
  WHERE username = @dashboard_owner
  LIMIT 1
);

START TRANSACTION;

DELETE uw
FROM users_widgets uw
JOIN dashboards d ON d.dashboard_id = uw.dashboard_id
WHERE d.user_id = @owner_id
  AND d.dashboard_name = @dashboard_name;

DELETE FROM dashboards
WHERE user_id = @owner_id
  AND dashboard_name = @dashboard_name;

INSERT INTO dashboards (user_id, dashboard_name, access)
VALUES (@owner_id, @dashboard_name, 1);

SET @dashboard_id := LAST_INSERT_ID();

INSERT INTO users_widgets
  (user_id, widget, col, `row`, size_x, size_y, title, refresh, settings, dashboard_id)
VALUES
  (@owner_id, 'device-summary-horiz', 1, 1, 20, 2, 'Device Summary', 60, '', @dashboard_id),
  (@owner_id, 'alerts', 1, 3, 7, 4, 'Active Alerts', 60, '', @dashboard_id),
  (@owner_id, 'availability-map', 8, 3, 7, 4, 'Availability Map', 60, '', @dashboard_id),
  (@owner_id, 'component-status', 15, 3, 6, 4, 'Poller / Service Status', 60, '', @dashboard_id),
  (@owner_id, 'top-devices', 1, 7, 10, 5, 'Top Devices by Traffic', 60, '', @dashboard_id),
  (@owner_id, 'top-interfaces', 11, 7, 10, 5, 'Top Interfaces', 60, '', @dashboard_id),
  (@owner_id, 'eventlog', 1, 12, 10, 5, 'Recent Eventlog', 60, '', @dashboard_id),
  (@owner_id, 'device-types', 11, 12, 5, 5, 'Device Types / Distribution', 300, '', @dashboard_id),
  (@owner_id, 'worldmap', 16, 12, 5, 5, 'Network Overview', 300, '', @dashboard_id);

COMMIT;

SELECT @dashboard_id AS dashboard_id;
