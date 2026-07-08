-- =============================================================================
-- banking-workflow-reference : reporting views
-- Run after 01_schema.sql (and 02_seed.sql if you want data to look at).
-- =============================================================================

-- Cases that are still active (not closed or rejected).
CREATE OR REPLACE VIEW v_open_cases AS
SELECT c.case_reference,
       c.title,
       c.status,
       c.priority,
       u.display_name AS owner,
       c.created_at
FROM   workflow_case c
LEFT JOIN app_user u ON u.user_id = c.owner_user_id
WHERE  c.status NOT IN ('CLOSED', 'REJECTED');

-- SLAs that are breached, or overdue and not yet completed.
CREATE OR REPLACE VIEW v_sla_breaches AS
SELECT c.case_reference,
       s.sla_name,
       s.due_at,
       s.completed_at,
       s.state
FROM   sla_tracking s
JOIN   workflow_case c ON c.case_id = s.case_id
WHERE  s.state = 'BREACHED'
   OR  (s.completed_at IS NULL AND s.due_at < now());

-- Approval steps still awaiting a decision.
CREATE OR REPLACE VIEW v_pending_approvals AS
SELECT c.case_reference,
       a.step_number,
       a.decision
FROM   approval a
JOIN   workflow_case c ON c.case_id = a.case_id
WHERE  a.decision = 'PENDING'
ORDER  BY c.case_reference, a.step_number;
