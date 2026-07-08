-- =============================================================================
-- banking-workflow-reference : seed data
-- Fictional data only. Names are famous computer scientists so it is obvious
-- the data is not real. Run after 01_schema.sql.
-- =============================================================================

INSERT INTO role (code, name) VALUES
    ('ADMIN',        'Administrator'),
    ('CASE_MANAGER', 'Case Manager'),
    ('CASE_OFFICER', 'Case Officer'),
    ('APPROVER',     'Approver'),
    ('AUDITOR',      'Auditor');

INSERT INTO app_user (username, display_name, role_id) VALUES
    ('admin',    'System Admin',      (SELECT role_id FROM role WHERE code = 'ADMIN')),
    ('ghopper',  'Grace Hopper',      (SELECT role_id FROM role WHERE code = 'CASE_MANAGER')),
    ('aturing',  'Alan Turing',       (SELECT role_id FROM role WHERE code = 'CASE_OFFICER')),
    ('alovelace','Ada Lovelace',      (SELECT role_id FROM role WHERE code = 'APPROVER')),
    ('kjohnson', 'Katherine Johnson', (SELECT role_id FROM role WHERE code = 'AUDITOR'));

INSERT INTO workflow_case (case_reference, title, status, priority, owner_user_id, created_by, closed_at) VALUES
    ('CASE-2026-000123', 'Account review request',   'PENDING_APPROVAL', 'HIGH',
        (SELECT user_id FROM app_user WHERE username = 'ghopper'),
        (SELECT user_id FROM app_user WHERE username = 'aturing'), NULL),
    ('CASE-2026-000124', 'Standard onboarding check', 'IN_REVIEW', 'MEDIUM',
        (SELECT user_id FROM app_user WHERE username = 'ghopper'),
        (SELECT user_id FROM app_user WHERE username = 'aturing'), NULL),
    ('CASE-2026-000125', 'Document verification',     'CLOSED', 'LOW',
        (SELECT user_id FROM app_user WHERE username = 'ghopper'),
        (SELECT user_id FROM app_user WHERE username = 'aturing'), now() - interval '4 days');

INSERT INTO task (task_reference, case_id, name, state, assigned_user_id, due_at, completed_at) VALUES
    ('TASK-0001', (SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000123'),
        'Initial review',     'COMPLETED',   (SELECT user_id FROM app_user WHERE username = 'aturing'),
        now() - interval '1 day', now() - interval '1 day'),
    ('TASK-0002', (SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000123'),
        'Approver sign-off',  'OPEN',        (SELECT user_id FROM app_user WHERE username = 'alovelace'),
        now() + interval '1 day', NULL),
    ('TASK-0003', (SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000124'),
        'Collect documents',  'IN_PROGRESS', (SELECT user_id FROM app_user WHERE username = 'aturing'),
        now() + interval '2 days', NULL);

INSERT INTO approval (case_id, step_number, decision, decided_by, decided_at, comment) VALUES
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000123'),
        1, 'PENDING', NULL, NULL, NULL),
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000125'),
        1, 'APPROVED', (SELECT user_id FROM app_user WHERE username = 'alovelace'),
        now() - interval '4 days', 'Documentation complete.');

INSERT INTO sla_tracking (case_id, sla_name, target_minutes, started_at, due_at, completed_at, state) VALUES
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000123'),
        'Approval SLA', 2880, now() - interval '1 day', now() + interval '1 day', NULL, 'ON_TRACK'),
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000124'),
        'Review SLA',   1440, now() - interval '2 days', now() - interval '1 day', NULL, 'BREACHED'),
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000125'),
        'Review SLA',   1440, now() - interval '5 days', now() - interval '4 days', now() - interval '4 days', 'MET');

INSERT INTO audit_event (case_id, action, actor_user_id, actor_role_code, detail, correlation_id, occurred_at) VALUES
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000123'),
        'CASE_CREATED',   (SELECT user_id FROM app_user WHERE username = 'aturing'), 'CASE_OFFICER',
        '{"channel":"web"}', '9f1c2d3e-4b5a-6789-0abc-def012345678', now() - interval '2 days'),
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000123'),
        'STATUS_CHANGED', (SELECT user_id FROM app_user WHERE username = 'ghopper'), 'CASE_MANAGER',
        '{"from":"IN_REVIEW","to":"PENDING_APPROVAL"}', '9f1c2d3e-4b5a-6789-0abc-def012345679', now() - interval '1 day'),
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000125'),
        'APPROVAL_GRANTED', (SELECT user_id FROM app_user WHERE username = 'alovelace'), 'APPROVER',
        '{"step":1}', 'a1b2c3d4-e5f6-7890-abcd-ef0123456780', now() - interval '4 days');

INSERT INTO attachment_metadata (case_id, file_name, content_type, size_bytes, storage_uri, uploaded_by, checksum_sha256) VALUES
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000123'),
        'application-form.pdf', 'application/pdf', 204800,
        'file-store://example/CASE-2026-000123/application-form.pdf',
        (SELECT user_id FROM app_user WHERE username = 'aturing'), repeat('a', 64)),
    ((SELECT case_id FROM workflow_case WHERE case_reference = 'CASE-2026-000124'),
        'id-document.png', 'image/png', 102400,
        'file-store://example/CASE-2026-000124/id-document.png',
        (SELECT user_id FROM app_user WHERE username = 'aturing'), repeat('b', 64));
