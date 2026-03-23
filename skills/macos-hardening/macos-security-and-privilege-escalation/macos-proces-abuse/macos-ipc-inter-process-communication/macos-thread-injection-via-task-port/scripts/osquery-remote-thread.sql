-- osquery queries for detecting macOS thread injection
-- Requires osquery >= 5.8 with EndpointSecurity support
-- Run with: osqueryi --flagfile /etc/osquery/osquery.flags

-- Query 1: Recent remote thread creation events
SELECT 
    timestamp,
    target_pid,
    source_pid,
    target_path,
    source_path,
    target_comm,
    source_comm
FROM es_process_events
WHERE event_type = 'REMOTE_THREAD_CREATE'
ORDER BY timestamp DESC
LIMIT 50;

-- Query 2: Task port authorization requests
SELECT 
    timestamp,
    target_pid,
    source_pid,
    target_path,
    source_path,
    result
FROM es_process_events
WHERE event_type = 'AUTH_GET_TASK'
ORDER BY timestamp DESC
LIMIT 50;

-- Query 3: Thread state modifications (macOS 14+)
SELECT 
    timestamp,
    target_pid,
    source_pid,
    target_path,
    source_path
FROM es_process_events
WHERE event_type = 'THREAD_SET_STATE'
ORDER BY timestamp DESC
LIMIT 50;

-- Query 4: Aggregate by source process (potential attacker)
SELECT 
    source_pid,
    source_path,
    COUNT(*) as event_count,
    GROUP_CONCAT(DISTINCT event_type) as event_types
FROM es_process_events
WHERE event_type IN ('REMOTE_THREAD_CREATE', 'AUTH_GET_TASK', 'THREAD_SET_STATE')
GROUP BY source_pid, source_path
ORDER BY event_count DESC
LIMIT 20;

-- Query 5: Target processes being attacked
SELECT 
    target_pid,
    target_path,
    COUNT(*) as attack_count,
    GROUP_CONCAT(DISTINCT source_pid) as attacking_pids
FROM es_process_events
WHERE event_type = 'REMOTE_THREAD_CREATE'
GROUP BY target_pid, target_path
ORDER BY attack_count DESC
LIMIT 20;
