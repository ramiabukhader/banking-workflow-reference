-- =============================================================================
-- banking-workflow-reference : schema
-- Generic enterprise case-management workflow schema for PostgreSQL 13+.
--
-- This is a GENERIC, EDUCATIONAL reference. It is NOT a real bank schema and
-- contains no proprietary or copied internal logic. All data is fictional.
-- =============================================================================

-- Clean slate (safe to re-run) -------------------------------------------------
DROP VIEW  IF EXISTS v_pending_approvals CASCADE;
DROP VIEW  IF EXISTS v_sla_breaches      CASCADE;
DROP VIEW  IF EXISTS v_open_cases        CASCADE;

DROP TABLE IF EXISTS attachment_metadata CASCADE;
DROP TABLE IF EXISTS audit_event         CASCADE;
DROP TABLE IF EXISTS sla_tracking        CASCADE;
DROP TABLE IF EXISTS approval            CASCADE;
DROP TABLE IF EXISTS task                CASCADE;
DROP TABLE IF EXISTS workflow_case       CASCADE;
DROP TABLE IF EXISTS app_user            CASCADE;
DROP TABLE IF EXISTS role                CASCADE;

DROP TYPE  IF EXISTS sla_state         CASCADE;
DROP TYPE  IF EXISTS approval_decision CASCADE;
DROP TYPE  IF EXISTS task_state        CASCADE;
DROP TYPE  IF EXISTS priority_level    CASCADE;
DROP TYPE  IF EXISTS case_status       CASCADE;

-- Enumerated domains -----------------------------------------------------------
CREATE TYPE case_status       AS ENUM ('DRAFT','SUBMITTED','IN_REVIEW','PENDING_APPROVAL','APPROVED','REJECTED','CLOSED');
CREATE TYPE priority_level    AS ENUM ('LOW','MEDIUM','HIGH','CRITICAL');
CREATE TYPE task_state        AS ENUM ('OPEN','IN_PROGRESS','COMPLETED','CANCELLED');
CREATE TYPE approval_decision AS ENUM ('PENDING','APPROVED','REJECTED');
CREATE TYPE sla_state         AS ENUM ('ON_TRACK','AT_RISK','BREACHED','MET');

-- Reference data: roles and users ---------------------------------------------
CREATE TABLE role (
    role_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code     text NOT NULL UNIQUE,
    name     text NOT NULL
);

CREATE TABLE app_user (
    user_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username     text NOT NULL UNIQUE,
    display_name text NOT NULL,
    role_id      bigint NOT NULL REFERENCES role(role_id),
    is_active    boolean NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now()
);

-- Core entity: a case is the single source of truth for a unit of work --------
CREATE TABLE workflow_case (
    case_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_reference text NOT NULL UNIQUE,          -- immutable business key
    title          text NOT NULL,
    status         case_status    NOT NULL DEFAULT 'DRAFT',
    priority       priority_level NOT NULL DEFAULT 'MEDIUM',
    owner_user_id  bigint REFERENCES app_user(user_id),
    created_by     bigint NOT NULL REFERENCES app_user(user_id),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    closed_at      timestamptz,
    CONSTRAINT chk_closed_consistency
        CHECK ((status IN ('CLOSED','REJECTED')) = (closed_at IS NOT NULL))
);

-- Work items belonging to a case ----------------------------------------------
CREATE TABLE task (
    task_id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_reference   text NOT NULL UNIQUE,
    case_id          bigint NOT NULL REFERENCES workflow_case(case_id) ON DELETE CASCADE,
    name             text NOT NULL,
    state            task_state NOT NULL DEFAULT 'OPEN',
    assigned_role_id bigint REFERENCES role(role_id),
    assigned_user_id bigint REFERENCES app_user(user_id),
    due_at           timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    completed_at     timestamptz
);

-- Approval steps (segregation of duties) --------------------------------------
CREATE TABLE approval (
    approval_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_id     bigint NOT NULL REFERENCES workflow_case(case_id) ON DELETE CASCADE,
    step_number integer NOT NULL CHECK (step_number > 0),
    decision    approval_decision NOT NULL DEFAULT 'PENDING',
    decided_by  bigint REFERENCES app_user(user_id),
    decided_at  timestamptz,
    comment     text,
    CONSTRAINT uq_approval_step UNIQUE (case_id, step_number),
    CONSTRAINT chk_decision_consistency CHECK (
        (decision = 'PENDING'  AND decided_by IS NULL     AND decided_at IS NULL)
     OR (decision <> 'PENDING' AND decided_by IS NOT NULL AND decided_at IS NOT NULL)
    )
);

-- SLA tracking per case --------------------------------------------------------
CREATE TABLE sla_tracking (
    sla_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_id        bigint NOT NULL REFERENCES workflow_case(case_id) ON DELETE CASCADE,
    sla_name       text NOT NULL,
    target_minutes integer NOT NULL CHECK (target_minutes > 0),
    started_at     timestamptz NOT NULL DEFAULT now(),
    due_at         timestamptz NOT NULL,
    completed_at   timestamptz,
    state          sla_state NOT NULL DEFAULT 'ON_TRACK'
);

-- Append-only audit trail ------------------------------------------------------
CREATE TABLE audit_event (
    event_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_id         bigint REFERENCES workflow_case(case_id) ON DELETE SET NULL,
    action          text NOT NULL,                 -- controlled vocabulary
    actor_user_id   bigint REFERENCES app_user(user_id),
    actor_role_code text,
    detail          jsonb NOT NULL DEFAULT '{}'::jsonb,
    correlation_id  uuid,
    occurred_at     timestamptz NOT NULL DEFAULT now()
);

-- Attachment METADATA only (no binary content is stored in the database) ------
CREATE TABLE attachment_metadata (
    attachment_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_id         bigint NOT NULL REFERENCES workflow_case(case_id) ON DELETE CASCADE,
    file_name       text NOT NULL,
    content_type    text NOT NULL,
    size_bytes      bigint NOT NULL CHECK (size_bytes >= 0),
    storage_uri     text NOT NULL,                 -- pointer to an external store
    uploaded_by     bigint REFERENCES app_user(user_id),
    uploaded_at     timestamptz NOT NULL DEFAULT now(),
    checksum_sha256 char(64)
);

-- Indexes for common access paths ---------------------------------------------
CREATE INDEX idx_case_status     ON workflow_case(status);
CREATE INDEX idx_task_case       ON task(case_id);
CREATE INDEX idx_task_state      ON task(state);
CREATE INDEX idx_approval_case   ON approval(case_id);
CREATE INDEX idx_sla_case        ON sla_tracking(case_id);
CREATE INDEX idx_audit_case      ON audit_event(case_id);
CREATE INDEX idx_audit_occurred  ON audit_event(occurred_at);
CREATE INDEX idx_attach_case     ON attachment_metadata(case_id);

-- Keep updated_at current on any case change ----------------------------------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_case_updated
    BEFORE UPDATE ON workflow_case
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
