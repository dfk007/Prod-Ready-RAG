# Cursor AI Workflow Rules

## Phase and Sub-Phase Execution Protocol

When working on any phase or sub-phase from project documentation (e.g., `integration-plan.md`, `db-models-migrations-phase-1-1.md`):

### REQUIRED WORKFLOW:

1. **At the START of each sub-phase:**
   - Clearly announce: "Starting [Sub-phase Name]: [Description]"
   - List what will be done in this sub-phase
   - Show the specific tasks that will be completed

2. **During execution:**
   - Follow the exact flow and sequence as specified in the documentation
   - Do not skip steps or change the order unless explicitly requested
   - Complete all tasks listed for the sub-phase

3. **At the END of each sub-phase:**
   - Clearly announce: "Sub-phase [Name] complete: [Summary]"
   - List what was accomplished
   - State what the next phase/sub-phase is that we're proceeding to
   - Provide a brief summary of what will happen next

### Example Format:

Starting Sub-phase 1.1.1: Create app/models/user.py

• Creating the User model with fields: id, email, password_hash, created_at, role, subscription_status.
• Adding relationships: one-to-one with Profile, one-to-many with Conversations, MoodLogs, Subscriptions, Exports.

[Execute the work...]

Sub-phase 1.1.1 complete: Created app/models/user.py with User model (id, email, password_hash, created_at, role, subscription_status) and relationships.

Proceeding to Sub-phase 1.1.2: Create app/models/profile.py

### Additional Guidelines:

- Always reference the source documentation when starting a phase
- If documentation is unclear, ask for clarification before proceeding
- Maintain consistency with existing code patterns and project structure
- Verify each step before moving to the next
- Report any issues or blockers immediately

---

# Cursor Rules for Error Handling and Debugging

## Global Error Analysis Rule

**When the user shares any log, error message, traceback, or exception:**

1. **ALWAYS provide a structured error analysis that includes:**

   ### What Went Wrong
   - Clearly identify the root cause of the error
   - Explain the specific issue in plain language
   - Note any related context (environment, dependencies, configuration)

   ### The Fix
   - Provide a concrete solution with code changes when applicable
   - Include step-by-step instructions if needed
   - Suggest preventive measures to avoid recurrence

   ### Current Status
   - Indicate whether the issue is resolved, partially resolved, or requires further action
   - Note any remaining work or follow-up steps needed

   ### File and Line References
   - **ALWAYS specify the exact file path** (relative to project root)
   - **ALWAYS include line numbers** where the error occurred
   - **ALWAYS include line numbers** for any code that needs to be changed
   - Use format: `filename.py:line_number` or `filename.py:start_line-end_line` for ranges
   - If multiple files are involved, list all of them with their respective line numbers

2. **Error Response Format:**

   ```
   ## Error Analysis

   **File:** `path/to/file.py:line_number`
   
   **What Went Wrong:**
   [Clear explanation of the issue]
   
   **The Fix:**
   [Specific solution with code changes]
   
   **Current Status:**
   [Resolution status and next steps]
   
   **Affected Files and Lines:**
   - `file1.py:10-15` - Error location
   - `file2.py:25` - Related code
   ```

3. **Additional Requirements:**
   - When showing code changes, use the exact file paths and line numbers
   - If the error spans multiple files, provide a complete breakdown for each file
   - Include relevant context from surrounding lines when explaining the error
   - Always verify file paths exist before referencing them
   - For tracebacks, map each stack frame to its file and line number

4. **For Logs and Warnings:**
   - Even for warnings or non-fatal logs, provide the same structured analysis
   - Include recommendations for addressing warnings
   - Note potential impact if warnings are ignored

## Code Quality Standards

- Always include file paths and line numbers in error explanations
- Provide actionable fixes, not just descriptions
- Verify solutions work before suggesting them
- Consider edge cases and related issues

