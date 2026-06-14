# Spec-Kit Extended Flow: Migration von Preset zu Preset+Extension

## Executive Summary

Das `spec-kit-extended-flow` Preset hat ein fundamentales Architekturproblem: Es liefert Commands aus, obwohl Presets laut Spec-Kit-Design nur Templates bereitstellen sollten. Dies führt zu einem Bug, bei dem Commands mit dreiteiligen Namen (`speckit.extendedflow.*`) nicht registriert werden, es sei denn, ein Workaround-Verzeichnis existiert.

**Lösung:** Aufteilung in drei unabhängige Komponenten:
- **Preset** → Templates (review-findings, documentation)
- **Extension** → Commands (review, fix, documentation, etc.)
- **Workflow** → Orchestrierung (bereits separat installiert)

---

## Problemstellung

### Symptome
- Commands `speckit.extendedflow.*` werden nach `specify preset add` nicht in `.agents/commands/` oder `.opencode/skills/` deployed
- `registered_commands` in `.specify/presets/.registry` ist leer `{}`
- Workflow-Schritte schlagen fehl mit: `Error: Command not found: "speckit.extendedflow.review"`

### Workaround (aktuell)
```bash
mkdir -p .specify/extensions/extendedflow
specify preset remove spec-kit-extended-flow
specify preset add --dev ../../spec-kit-extended-flow
```

Das leere Verzeichnis gaukelt dem Filter vor, dass es sich um eine Extension handelt.

---

## Root Cause Analysis

### Der Bug in Spec-Kit (Issue #2862)

**Betroffene Code-Stellen in `src/specify_cli/presets.py`:**
- `_register_commands()` (Zeilen 618-629)
- `_register_skills()` (Zeilen 1237-1247)
- `install_from_directory()` (Zeilen 1589-1602)

**Filter-Logik:**
```python
# Filter out extension command overrides if the extension isn't installed.
extensions_dir = self.project_root / ".specify" / "extensions"
filtered = []
for cmd in command_templates:
    parts = cmd["name"].split(".")
    if len(parts) >= 3 and parts[0] == "speckit":
        ext_id = parts[1]
        if not (extensions_dir / ext_id).is_dir():
            continue          # ← silently skips the command
    filtered.append(cmd)
```

**Problem:** Der Filter kann nicht unterscheiden zwischen:
1. **Extension Command Overrides** (sollten übersprungen werden, wenn Extension fehlt)
2. **Preset-provided Commands** (sollten immer registriert werden)

Beide verwenden dreiteilige Namen (`speckit.<domain>.<cmd>`), daher werden alle dreiteiligen Namen gefiltert.

### Upstream-Status

**Issue #2862:** [Bug: preset commands with 3-part names silently skipped](https://github.com/github/spec-kit/issues/2862)

**PRs #2863 und #2865:** Beide wurden am 8. Juni 2026 von @mnriem **geschlossen, nicht gemerged** mit dem Kommentar:

> "A preset is not supposed to deliver commands. If you are delivering commands you should be delivering an extension, not a preset"

**Konsequenz:** Es wird **keinen Upstream-Fix** geben. Das Verhalten ist "by design".

---

## Spec-Kit Architektur

### Drei unabhängige Konzepte

| Komponente | Zweck | Manifest | Installiert in | Liefert |
|------------|-------|----------|----------------|---------|
| **Preset** | Templates & Output-Formate | `preset.yml` | `.specify/presets/` | Templates, Scripts |
| **Extension** | Commands & Hooks | `extension.yml` | `.specify/extensions/` | Commands, Config, Hooks |
| **Workflow** | Orchestrierung & Steps | `workflow.yml` | `.specify/workflows/` | Step-Definitionen |

### Beispiel: Git Extension (korrekt)

```yaml
# .specify/extensions/git/extension.yml
extension:
  id: git
  name: "Git Branching Workflow"
  version: "1.0.0"

provides:
  commands:
    - name: speckit.git.feature
      file: commands/speckit.git.feature.md
    - name: speckit.git.commit
      file: commands/speckit.git.commit.md

hooks:
  before_specify:
    command: speckit.git.feature
  after_implement:
    command: speckit.git.commit
```

**Ergebnis:** Commands werden automatisch in alle Integration-Targets deployed:
- `.agents/commands/speckit.git.feature.md`
- `.opencode/skills/speckit-git-feature/`
- `.claude/commands/speckit.git.feature.md`
- etc.

### Beispiel: Extended Flow Preset (inkorrekt)

```yaml
# .specify/presets/spec-kit-extended-flow/preset.yml
preset:
  id: spec-kit-extended-flow
  version: "0.5.0"

provides:
  templates:
    - type: "template"
      name: "review-findings"
      file: templates/review-findings.md
    
    - type: "command"  # ❌ Sollte nicht in einem Preset sein!
      name: "speckit.extendedflow.review"
      file: commands/speckit.extendedflow.review.md
```

**Ergebnis:** Commands werden **nicht** deployed (außer mit Workaround).

---

## Lösung: Migration zu Preset+Extension

### Zielstruktur

```
spec-kit-extended-flow/
├── preset.yml              # Nur Templates
├── extension.yml           # Nur Commands (NEU)
├── workflow.yml            # Workflow (bleibt)
├── commands/               # Commands (bleiben)
│   ├── speckit.extendedflow.review.md
│   ├── speckit.extendedflow.fix.md
│   ├── speckit.extendedflow.documentation.md
│   ├── speckit.extendedflow.documentation-init.md
│   ├── speckit.extendedflow.finish.md
│   └── speckit.extendedflow.project-init.md
├── templates/              # Templates (bleiben)
│   ├── review-findings.md
│   └── documentation.md
└── scripts/                # Scripts (bleiben)
    ├── resolve-spec.sh
    ├── create-branch.sh
    └── extract-verdict.sh
```

### Neue `extension.yml`

```yaml
schema_version: "1.0"

extension:
  id: extendedflow
  name: "Spec-Kit Extended Flow"
  version: "0.5.0"
  description: "QA review loop, automated documentation reconciliation, and issue-to-PR automation"
  author: "Markus Wondrak"
  repository: "https://github.com/markuswondrak/spec-kit-extended-flow"
  license: "MIT"

requires:
  speckit_version: ">=0.8.5"

provides:
  commands:
    - name: speckit.extendedflow.review
      file: commands/speckit.extendedflow.review.md
      description: "QA Review agent — analyzes implementation against spec and outputs PASS/FAIL"
    
    - name: speckit.extendedflow.fix
      file: commands/speckit.extendedflow.fix.md
      description: "Fix agent — makes targeted, surgical fixes for review findings"
    
    - name: speckit.extendedflow.documentation
      file: commands/speckit.extendedflow.documentation.md
      description: "Documentation agent — maintains layered documentation, flags code-vs-docs conflicts"
    
    - name: speckit.extendedflow.documentation-init
      file: commands/speckit.extendedflow.documentation-init.md
      description: "Documentation init agent — bootstraps layered documentation structure"
    
    - name: speckit.extendedflow.finish
      file: commands/speckit.extendedflow.finish.md
      description: "Finish agent — cleans up temporary run artifacts, commits changes, opens PR"
    
    - name: speckit.extendedflow.project-init
      file: commands/speckit.extendedflow.project-init.md
      description: "Project init agent — analyzes project and contextualizes Spec-Kit templates"

tags:
  - "qa"
  - "review"
  - "documentation"
  - "workflow"
```

### Angepasste `preset.yml`

```yaml
schema_version: "1.0"

preset:
  id: "spec-kit-extended-flow"
  name: "Spec-Kit Extended Flow"
  version: "0.5.0"
  description: "SDD workflow with QA review loop and automated documentation reconciliation"
  author: "Markus Wondrak"
  repository: "https://github.com/markuswondrak/spec-kit-extended-flow"
  license: "MIT"

requires:
  speckit_version: ">=0.8.5"

provides:
  templates:
    - type: "template"
      name: "review-findings"
      file: "templates/review-findings.md"
      description: "Structured template for the Reviewer to log bugs, edge-case failures, or spec deviations"

    - type: "template"
      name: "documentation"
      file: "templates/documentation.md"
      description: "Structured report template for documentation reconciliation"

  tags:
  - "qa"
  - "review"
  - "documentation"
  - "workflow"
```

---

## Migrations-Schritte

### 1. Repository vorbereiten

```bash
cd /home/markus/workspace/spec-kit-extended-flow

# extension.yml erstellen (siehe oben)
# preset.yml anpassen (siehe oben)
```

### 2. Altes Preset deinstallieren

```bash
cd /home/markus/workspace/doc-simplifier/doc-simplifier-app

# Preset entfernen
specify preset remove spec-kit-extended-flow

# Workaround-Verzeichnis entfernen
rm -rf .specify/extensions/extendedflow
```

### 3. Neues Preset installieren (nur Templates)

```bash
specify preset add --dev ../../spec-kit-extended-flow
```

**Verifikation:**
```bash
cat .specify/presets/.registry | jq '.presets["spec-kit-extended-flow"]'
```

**Erwartet:**
```json
{
  "version": "0.5.0",
  "registered_commands": {},
  "registered_skills": []
}
```

### 4. Extension installieren (Commands)

```bash
specify extension add --dev ../../spec-kit-extended-flow
```

**Verifikation:**
```bash
cat .specify/extensions/.registry | jq '.extensions.extendedflow'
```

**Erwartet:**
```json
{
  "version": "0.5.0",
  "registered_commands": {
    "opencode": [
      "speckit.extendedflow.review",
      "speckit.extendedflow.fix",
      "speckit.extendedflow.documentation",
      "speckit.extendedflow.documentation-init",
      "speckit.extendedflow.finish",
      "speckit.extendedflow.project-init"
    ]
  }
}
```

### 5. Commands verifizieren

```bash
# Commands in Integration-Targets
ls -la .agents/commands/ | grep extendedflow
ls -la .opencode/skills/ | grep extendedflow

# Command-Resolution testen
specify preset resolve speckit.extendedflow.review
```

**Erwartet:**
```
speckit.extendedflow.review: 
/home/markus/workspace/doc-simplifier/doc-simplifier-app/.specify/extensions/extendedflow/commands/speckit.extendedflow.review.md
```

### 6. Workflow bleibt installiert

Der Workflow ist bereits separat installiert und muss nicht neu installiert werden:

```bash
specify workflow list
```

**Erwartet:**
```
Spec-Kit Extended Flow — SDD Lifecycle with QA Review and Documentation Reconciliation (spec-kit-extended-flow) v0.5.0
```

---

## Vorteile der neuen Architektur

### 1. Kein Workaround mehr nötig
- Commands werden automatisch deployed
- Kein leeres Verzeichnis `.specify/extensions/extendedflow/` erforderlich
- Entspricht dem Spec-Kit-Design

### 2. Klare Trennung der Verantwortlichkeiten
- **Preset:** Templates (Output-Formate)
- **Extension:** Commands (Agent-Prompts)
- **Workflow:** Orchestrierung (Steps)

### 3. Bessere Wartbarkeit
- Jede Komponente kann unabhängig versioniert werden
- Klare Abhängigkeiten
- Einfachere Tests

### 4. Zukunftssicher
- Entspricht der offiziellen Spec-Kit-Architektur
- Keine Abhängigkeit von Bugs oder Workarounds
- Kompatibel mit zukünftigen Spec-Kit-Versionen

---

## Testing

### Vor der Migration

```bash
# Aktuellen Zustand dokumentieren
specify preset list
specify extension list
specify workflow list

# Command-Resolution testen
specify preset resolve speckit.extendedflow.review
# Erwartet: "not found" (ohne Workaround)
```

### Nach der Migration

```bash
# Preset und Extension verifizieren
specify preset list
specify extension list
specify workflow list

# Command-Resolution testen
specify preset resolve speckit.extendedflow.review
# Erwartet: Pfad zu .specify/extensions/extendedflow/commands/...

# Workflow testen
specify workflow run spec-kit-extended-flow \
  --input spec="Test feature for migration validation"
```

---

## Rollback-Plan

Falls Probleme auftreten:

```bash
# Extension entfernen
specify extension remove extendedflow

# Preset entfernen
specify preset remove spec-kit-extended-flow

# Workaround wiederherstellen
mkdir -p .specify/extensions/extendedflow
specify preset add --dev ../../spec-kit-extended-flow
```

---

## Referenzen

- **Spec-Kit Issue #2862:** [Bug: preset commands with 3-part names silently skipped](https://github.com/github/spec-kit/issues/2862)
- **Spec-Kit PR #2863:** [fix: register preset-provided namespaced commands](https://github.com/github/spec-kit/pull/2863) (geschlossen, nicht gemerged)
- **Spec-Kit PR #2865:** [fix: register preset commands with 3-part names](https://github.com/github/spec-kit/pull/2865) (geschlossen, nicht gemerged)
- **Spec-Kit Dokumentation:** Presets vs Extensions vs Workflows

---

## Zusammenfassung

Das `spec-kit-extended-flow` Preset verletzt die Spec-Kit-Architektur, indem es Commands in einem Preset ausliefert. Die Migration zu einer **Preset+Extension-Architektur** löst das Problem dauerhaft:

- ✅ Kein Workaround mehr nötig
- ✅ Entspricht dem Spec-Kit-Design
- ✅ Bessere Wartbarkeit
- ✅ Zukunftssicher

Die Migration ist straightforward und kann ohne Downtime durchgeführt werden.
