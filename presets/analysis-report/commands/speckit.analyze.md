## Analysis Report: Persist It

The Extended Flow reviews this command's findings at a human gate, which reads a
file. **Persist the complete analysis report to `FEATURE_DIR/analysis.md`.**

- `FEATURE_DIR` is the feature directory this command already resolves — the one
  holding `spec.md`, `plan.md`, and `tasks.md`.
- Write the report verbatim, in Markdown: the same content you output to the user.
- This write is permitted, and it is the **only** permitted file modification. It
  supersedes the read-only constraint stated later in this command for exactly
  this one file; `spec.md`, `plan.md`, `tasks.md`, and everything else stay
  untouched.
- If `FEATURE_DIR` cannot be determined, do not write anywhere else — report that
  in your final output instead.

{CORE_TEMPLATE}

## Final Step: Write the Report

Write the report you just produced to `FEATURE_DIR/analysis.md`, and state the
path you wrote in your final output.
