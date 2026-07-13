# Workflow Domain Glossary

This glossary defines the generic case-management terms used by the schema.
The model and examples are fictional; the definitions describe this reference
implementation rather than any real institution's process.

| Term | Meaning in this reference | Schema location |
|------|---------------------------|-----------------|
| **Workflow case** | The unit of work that moves through the lifecycle from `DRAFT` to `CLOSED` or `REJECTED`. A case owns its tasks, approvals, SLA records, audit events, and attachment metadata. | `workflow_case` |
| **Case reference** | An immutable, human-readable business key used in correspondence, searches, and audit evidence. It remains separate from the database-generated `case_id`. | `workflow_case.case_reference` |
| **Case owner** | The active user responsible for coordinating the case. Ownership can differ from the user who originally created it. | `workflow_case.owner_user_id` |
| **Case status** | The explicit lifecycle state of a case: `DRAFT`, `SUBMITTED`, `IN_REVIEW`, `PENDING_APPROVAL`, `APPROVED`, `REJECTED`, or `CLOSED`. | `case_status`, `workflow_case.status` |
| **Priority** | The relative urgency assigned to a case: `LOW`, `MEDIUM`, `HIGH`, or `CRITICAL`. It is independent of the case's lifecycle state. | `priority_level`, `workflow_case.priority` |
| **Task** | A discrete work item belonging to one case. It has its own stable reference, assignee, due time, and state. | `task` |
| **Task state** | The progress of a task: `OPEN`, `IN_PROGRESS`, `COMPLETED`, or `CANCELLED`. Completing a task does not implicitly change the parent case status. | `task_state`, `task.state` |
| **Approval** | A numbered decision step for a case. Pending approvals have no decider or decision time; completed decisions record both. | `approval` |
| **Approval decision** | The outcome of an approval step: `PENDING`, `APPROVED`, or `REJECTED`. | `approval_decision`, `approval.decision` |
| **Segregation of duties** | A governance control that separates approval authority from case editing or preparation, reducing the risk of one person controlling an entire decision. | `role`, `app_user`, `approval.decided_by` |
| **Role** | A stable set of responsibilities granted to users, such as case officer or approver. Roles support access rules without assigning permissions directly to individuals. | `role`, `app_user.role_id` |
| **SLA** | A service-level target for a case, expressed as target minutes plus start, due, and optional completion timestamps. A case can have more than one named target. | `sla_tracking` |
| **SLA state** | The current outcome of an SLA target: `ON_TRACK`, `AT_RISK`, `BREACHED`, or `MET`. | `sla_state`, `sla_tracking.state` |
| **Audit event** | An append-only record of a significant action, including who acted, when it occurred, optional structured detail, and a correlation ID. | `audit_event` |
| **Append-only** | A recordkeeping rule: new audit rows are inserted, while historical events are not edited or deleted by the application. This preserves the chronology of evidence. | `audit_event` |
| **Correlation ID** | A UUID that connects an audit event to the request, integration call, or process execution that caused it. | `audit_event.correlation_id` |
| **Attachment metadata** | Descriptive information about a case file—name, media type, size, checksum, uploader, and storage location—without storing the file bytes in PostgreSQL. | `attachment_metadata` |
| **Storage URI** | A pointer to a file in an external document store. It keeps binary content outside the transactional workflow database. | `attachment_metadata.storage_uri` |
| **Business key** | A stable identifier meaningful outside the database, such as `CASE-2026-000123` or `TASK-0001`. | `case_reference`, `task_reference` |
| **Surrogate key** | A database-generated identity used for joins and foreign keys, with no business meaning. | Columns such as `case_id`, `task_id`, and `approval_id` |
| **Reporting view** | A saved query that presents operational questions without exposing every table detail. This reference includes open cases, SLA breaches, and pending approvals. | `v_open_cases`, `v_sla_breaches`, `v_pending_approvals` |

For the lifecycle and governance rules behind these terms, see
[Business Flow & Governance Principles](business-flow.md). For table
relationships and attributes, see the [Entity Relationship Diagram](erd.md).
