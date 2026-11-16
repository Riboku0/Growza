# Istudy UI Report

A simplified mobile application for subject access, availability-based scheduling, and focused study.

**Mobile Application Development · Academic UI Design Report**  
**Platform:** Proposed Flutter mobile application

The revised design retains three main tabs: **Home, Study, and Schedule**. Students enter available weekdays and time windows. Session duration is assigned by the planning system rather than entered as a second time-budget field.

## 1 Introduction and Scope

### Abstract

This report specifies the revised user interface of Istudy, a student-focused mobile study application. The design preserves the original project’s account, schedule, focus-timer, break, and session-counter functions [1], while adding user-requested AI material analysis and planning [2]. A central revision removes redundant manual minute entry: after material analysis, the student supplies available weekdays and clock-time windows. The system then assigns session lengths and distributes study before the examination. The report documents the interaction sequence, screen rationale, constraints, and the distinction between prototype behavior and proposed production capability.

### 1.1 Problem and design objectives

A countdown alone does not explain which material to begin or how to allocate limited time before an examination. Conversely, excessive screens can make planning harder. The design therefore prioritizes direct timer access, a single featured subject area on Home, an integrated Study workflow, and explicit plan approval. It does not claim improved grades or learning outcomes; those effects require evaluation.

### 1.2 Scope boundary

The first version comprises sign-in, three main navigation tabs, subject input, material analysis, recurring availability, plan review, session access, and focus/break timing. AI is an extension to the original scope, which deferred AI coaching [1]. Social rooms, advanced analytics, gamification, and independent chapter management remain outside this design.

### 2 Functional Requirements

| ID | Required behavior |
| --- | --- |
| UI-01 | Offer Home, Study, and Schedule as the only main tabs. |
| UI-02 | Allow direct timer access without material analysis. |
| UI-03 | Analyze material before requesting recurring availability. |
| UI-04 | Derive available minutes from start/end times; assign focus duration automatically. |
| UI-05 | Respect exam dates, occupied periods, breaks, and approval before saving. |

Design basis: the supplied project report, agreed user requirements, and the user-provided Home reference. No usability study or live AI evaluation is represented as completed research.

## 3.1 Authentication

### Interaction and information

The sign-in interface provides the entry point to a student’s subjects and schedule. It contains email and password fields, a prominent Sign in action, and a registration link. Successful authentication should open Home, while unsuccessful attempts should return a clear, field-relevant message.

### Design rationale

A single dominant action limits competition for attention. The main application navigation is omitted before authentication because the student has not yet entered the workspace. Account creation and logout remain part of the project requirements [1].

### Prototype status

The illustrated sign-in screen is a proposed interface. Authentication, secure password handling, account creation, and account-specific data filtering are not connected in the browser demonstration.

## 3.2 Home and Subject Access

### Interaction and information

Home presents one shared subject panel. Swiping, selecting a position dot, or using the arrow controls changes the cover, subject name, topic, and progress within the same fixed area. Continue study opens the corresponding timer directly.

### Design rationale

This composition follows the supplied visual reference and prevents a long sequence of individually visible subject cards. A separate **Quick Study** shortcut preserves the original minimal-start requirement: a student can focus for 25 minutes without uploading material or using AI [1]. The supplied owl illustration appears only on the Quick Study button; the Istudy brand mark remains separate.

### Prototype status

The cover and topic-progress values are illustrative. Progress represents sample topics marked as covered; it is not evidence of comprehension or a verified PDF reading position. Navigation and the timer shortcut are interactive.

## 3.3 Study Workspace

### Interaction and information

Study combines subject access and AI-assisted setup within a single navigation destination. Each list entry identifies a subject, its estimated difficulty, its exam date, and the next study duration. Add a subject begins the setup sequence within this tab.

### Design rationale

The design maintains three main tabs: Home, Study, and Schedule. Analysis, availability, and plan review are temporary states inside Study rather than additional top-level destinations. This distinction preserves the simplified scope requested during design refinement [2].

### Prototype status

The prototype includes sample subjects and can append an approved sample subject. A separate chapter manager, social study features, and a standalone AI-chat workspace are deliberately excluded from the proposed first version.

## 3.4 Subject Input

### Interaction and information

The student supplies a subject name, exam date, and course material. The form does not request a daily number of minutes, a preferred session duration, or a self-assigned difficulty rating. The next action opens a sample material-analysis result.

### Design rationale

The input sequence separates content analysis from scheduling. Asking for the same time budget as both clock hours and minutes would duplicate information. The student therefore provides availability only in the subsequent availability state.

### Prototype status

The demonstration does not upload or read selected files. A production implementation must validate supported text-based files, report extraction failures, and explain the transfer of material before invoking an AI service.

## 3.5 AI Material Analysis

### Interaction and information

The analysis state communicates an estimated difficulty level, a concise explanation, identified topics, and estimated total focus effort. These outputs describe the material, rather than asking the student to rate difficulty or choose session length.

### Design rationale

The main action proceeds to availability. An overall workload estimate must precede planning because the system needs to compare required effort with the time available before the exam. Estimates should remain revisable when material or exam scope changes.

### Prototype status

The displayed result uses a fixed sample Biology analysis with an estimated six hours of focus. It is not an actual model response. Content-specific difficulty estimation and evidence-based topic extraction remain integration work.

## 3.6 Availability Input

### Interaction and information

After reviewing the analysis, the student selects available weekdays and provides a start and end time. For example, Monday, Wednesday, and Saturday from 17:00 to 19:00 define recurring two-hour windows. The interface calculates their duration automatically.

### Design rationale

No separate 60-minute field is required. Availability is a scheduling constraint, while focus duration is a planning output. The simplified prototype applies one time window to the selected weekdays; different windows per day may be added only if the project requires them.

### Prototype status

The form rejects empty weekday selections, reversed time ranges, and windows shorter than the demonstration’s minimum viable block. The example uses October 26, 2026 as a fixed planning date for reproducible review.

## 3.7 Plan Review and Approval

### Interaction and information

The review state presents a chronological proposal across available dates before the exam. Each entry identifies the topic, date, start time, assigned focus duration, and break allowance. The student approves the plan before it is added to Schedule.

### Design rationale

The sample scheduler uses available windows, excludes dates on or after the exam, and avoids accepted sessions. Focus effort and break time are accounted for separately. When the available capacity is insufficient, the interface identifies the shortfall and requests adjusted availability rather than approving an incomplete plan.

### Prototype status

The demonstration distributes a fixed sample workload using deterministic rules. It demonstrates constraints and approval, not an intelligent learning-optimization algorithm. The full application must validate AI-generated suggestions against the same constraints.

## 3.8 Schedule and Session Access

### Interaction and information

Schedule groups accepted sessions by day and presents the subject, topic, start time, and focus duration. Start session opens the timer using the assigned duration. Draft proposals do not appear until the student approves them.

### Design rationale

A chronological list is sufficient for the first version and avoids monthly-calendar complexity. The figure shows an excerpt of the accepted Biology plan; the complete demonstration retains all approved entries. Manual activity creation, editing, deletion, history, and reminders remain requirements inherited from the original project [1].

### Prototype status

The browser prototype retains data in memory only. Durable local storage, ownership by authenticated user, and notification maintenance must be implemented in Flutter. Replanning should preserve completed work and replace rather than duplicate future sessions.

## 3.9 Focus and Break Timer

### Interaction and information

The timer displays remaining time prominently and supports start, pause, resume, and reset. Quick focus defaults to 25 minutes, while a scheduled session uses its assigned duration. At focus completion, the demonstration increments the focus counter and moves to a five-minute break.

### Design rationale

The timer is reachable from Home, Study, and Schedule. A lightweight help area provides an example hint without introducing a fourth tab. Returning to Home preserves the running timer within the current browser session. The break begins in a ready state and is started explicitly in this demonstration.

### Prototype status

The countdown is an interface demonstration based on foreground ticks. Accurate background recovery, app-restart recovery, end alerts, reset confirmation, and reliable notification permissions require separate implementation and device testing.

## 4 Implementation and Evaluation

### 4.1 Proposed architecture

A Flutter implementation can separate authentication, subject storage, AI analysis, constraint validation, scheduling, and timer state. AI requests should use a secure backend rather than an embedded provider key. Files are study data, not executable instructions. Only the material selected by the student should be submitted for analysis.

| Record | Minimum information |
| --- | --- |
| Subject | ID, owner ID, name, source reference, exam date, analysis result. |
| Availability | Owner ID, selected weekdays, local start/end times. |
| Plan / Session | Subject ID, version/approval, topic, date, start time, focus duration, break allowance, status. |

### 4.2 Validation approach

Prototype checks exercise removal of manual minute entry, invalid-window rejection, proposal review before saving, approved-session visibility, timer-duration transfer, and narrow-screen layout. The Home panel is checked with arrows, dots, and swipe input. A sample workload produces **11 sessions · 360 focus minutes**; this is a demonstration result, not an AI-performance measurement. Production tests must verify date boundaries, conflicts across subjects, break occupancy, duplicate approval, account separation, and timer restoration.

### 4.3 Limitations

The browser demonstration uses sample analysis, deterministic scheduling rules, in-memory records, and a fixed example date. It does not provide live authentication, actual content extraction, durable storage, notifications, or reliable background timing. The sign-in illustration is a proposed UI. No user study has been conducted, and progress values and file covers are illustrative.

### 5 Conclusion

The revised design keeps the application compact while clarifying responsibility: students specify material, examination deadlines, and availability; the planning system estimates difficulty and effort, assigns session durations, and proposes a schedule. Students retain approval over the final plan. The resulting interface remains organized around Home, Study, and Schedule.

### References

[1] Alexander and Osama. (2026). *Istudy Study Timer Application: Final / Group Project Report, updated version.* Mobile Application course. User-supplied document, Istudy_docx.docx.

[2] Project stakeholder. (2026, October 25-26). *Istudy interface and planning requirements.* User-provided design instructions and Home reference image, recorded during project refinement. Unpublished project requirements.

### Companion Files

- [Interactive design](Istudy-Design.html)
- [Quick Study icon](Quick-Study-Icon.png)
