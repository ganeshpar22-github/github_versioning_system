# 🚀 Crew Integration System: Version Number Generator

This repository provides a modern, cloud-native solution for generating and publishing release version numbers. It replaces legacy BER infrastructure with a fully automated, deterministic pipeline hosted on GitHub Actions.

---

## 1. High-Level Architecture
The system functions as a **Decoupled Static Site Generator (SSG)**:
*   **Data Source Layer:** Individual release branches containing branch metadata (`/bin/branch.nfo`).
*   **Orchestration Layer:** A GitHub Actions runner that executes a central orchestrator to aggregate data across all branches.
*   **Validation Layer:** Automated quality gates that verify W3C HTML compliance and JSON structure before publication.
*   **Publication Layer:** A public-facing site hosted on **GitHub Pages** serving legacy-compatible endpoints.

---

## 2. Versioning Logic
The system implements the **Modern Versioning Pattern**: `<Year>.<Release>.<Weeks>.<Days>`

*   **Year & Release:** Extracted dynamically from the branch name (e.g., `2025.1`).
*   **Weeks:** The number of full 7-day periods passed since the date defined in `branch.nfo`.
*   **Days:** The number of days passed since the start of the current week (resets to 0 every 7 days).

### Special Version Constants
*   **Master Infinity (`0.0.0`):** Used for parameters in the `master` branch with no expiration.
*   **Release Infinity (`X.X.999`):** Used to support release branches for up to 19 years.
*   **Next Release Link (`X.X.1000`):** A symbolic version used to close parameters in a current release while maintaining them in the next.

---

## 3. Branch Structure and Naming Rules
*   **`master`:** The primary branch. It contains documentation, CI/CD configurations, utility scripts, and GitHub Pages source templates.
*   **`release/crew-YYYY.R`:** Dedicated release branches (e.g., `release/crew-2025.1`).
    *   **Requirement:** Must contain `/bin/branch.nfo` with a valid `YYYY-MM-DD` date.
    *   **Requirement:** Must contain `/bin/version.sh` to calculate its specific version.

---

## 4. Daily Version Generation (Automation)
The system is designed for **Zero Manual Intervention**:
1.  **Trigger:** A GitHub Workflow runs daily at **00:05 UTC** or upon manual trigger (`workflow_dispatch`).
2.  **Collection:** The `release-orchestrator.sh` script discovers all release branches using `git for-each-ref`.
3.  **Calculation:** The runner iterates through each branch, executes the local version logic, and stores the results.
4.  **Cleanup:** The runner returns to the `master` branch context to ensure environment stability for validation.

---

## 5. Production of HTML and JSON
The orchestrator script produces two primary files inside the `site_output/` directory:
*   **`release.html`:** A W3C-compliant document featuring a version table for human verification.
*   **`release.json`:** A machine-readable file following the exact schema of the legacy CIS endpoint.
*   **Parity:** Both files are generated within the same loop to ensure the data is **identical and deterministic**.

---

## 6. Developer Guide: Adding New Release Branches
To onboard a new release (e.g., `2026.1`):
1.  **Branching:** Create a new branch named `release/crew-2026.1`.
2.  **Metadata:** Commit `/bin/branch.nfo` with the official release start date.
3.  **Master Update:** In the `master` branch, update `MASTER_PREFIX` and `MASTER_ANCHOR_DATE` in `scripts/utilityscript.sh` to begin the next development cycle.
4.  **Deployment:** Push both changes. The next daily run will automatically include the new branch.

---

## 7. Troubleshooting & Production Readiness
### Quality Gates
*   **CI/CD Failure:** The pipeline is configured to fail if validation fails, preventing broken files from being published.
*   **Retention:** All build logs and artifacts are retained for **7 days** to support audit and troubleshooting requirements.

### Common Issues
