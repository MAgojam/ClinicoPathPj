# ClinicoPathPj and the Pj service: diagnostic comparison

Revision: **26 October 2026 â€” Agente_Pj / Maurizio Agosti**.
This is an experimental branch of Maurizio's fork, based on Serdar Balci's
ClinicoPathPj commit `56e02f6640678908948d5826e3b44a64166aab0a`.
It is not an official upstream release. Original authorship, maintainer and GPL
license are preserved. No pull request to upstream is opened by this work.

## Install and compare

Install [Pj 1.3.0 or newer](https://github.com/MAgojam/Pj/releases/tag/v1.3.0),
choosing the JMO matching your OS/architecture, and restart jamovi. Build this
branch using the upstream macOS procedure (`Rscript --vanilla tools/build.R`,
or `--build-only` then sideload the resulting JMO). This branch retains the
package identity **ClinicoPathPj**: sideloading replaces an installed copy of
that module; it does not install alongside upstream under a new identity.
Pj is separately installed and is neither copied nor declared as a CRAN Imports
dependency. Without Pj, the original analyses and processx comparison remain
independent; only the Pj entry reports that Pj must be installed.

Open **Data Library â†’ ClinicoPathPj â†’ Diagnostic service test data** (180 synthetic
teaching observations). Add both analyses under **ClinicoPathPj â†’ Python bridge
comparison**:

- **Diagnostic cutoff - ClinicoPathPj bridge** uses the original `pydotdecision`
  computation, its processx runner, native SVG plot and native result tables.
- **Diagnostic cutoff - Pj service** calls the public Pj API, its system2 runner,
  native tables and linked D3 dotplot/ROC with AUC and Youden J. It offers
  jamovi Python and System Python; SciPy must exist in the selected interpreter.
  Bundled D3 is supplied by Pj, without a CDN.

Choose **Measurement**, **Reference**, positive **Positive**, rule **>=**,
criterion **Fewest errors**, and jamovi Python in the Pj entry. At applied
cutoff **4**, both must show TP=14, FP=0, FN=41, TN=125; at **0**, TP=55, FP=94,
FN=0, TN=31. Use identical data/options to compare native estimates and exact
confidence intervals. Changing preview alone does not update native tables.
**Apply cutoff to jamovi** saves the host's cutoff option and reruns its backend.
The number field, draggable threshold and ROC operating point are linked.
**Preview automatic cutoff** previews the chosen criterion's optimum;
**Restore applied cutoff** restores the saved cutoff. An unchanged applied
cutoff does not request a redundant run. A blank native cutoff means automatic.

## What is being compared

Reported elapsed time includes preparation, process startup, imports, calculations,
JSON and native result mapping, but excludes browser rendering. Pj additionally
prepares resources and computes the ROC. This is a comparison of complete
analysis routes, not a controlled processx-versus-system2 benchmark. Report first
and repeated runs separately; do not infer performance from one measurement.
Pj's synchronous service has no checkpoint callback; the original processx route
polls jamovi checkpoints to cancel stale analyses. Their cancellation behaviour
is not equivalent. Pj's timeout is per subprocess, not an overall wall-clock cap.

ROC/AUC uses all complete rows including ties; hiding correct points is only a
visual filter. Cutoff optimization needs independent validation. Clopperâ€“Pearson
intervals assume independent rows and a fixed cutoff, ignoring selection
uncertainty. Predictive values depend on sample group proportions. The Pj entry
accepts at most 5,000 complete rows and uses a linear measurement axis. It does
not claim complete feature parity with the upstream analysis.

## Source map and build behaviour

`R/pjDiagnostic.b.R` is the host R6 caller; `R/mzPj_connect.R` discovers the
installed sibling Pj and requires version >=1.3.0 / service API 1, without
changing global `.libPaths()`. `inst/pj-service/diagnostic.py` computes the ROC
and exact intervals; `cutoff.html` implements D3 interaction and `window.setOption`.
The host validates replacement results before changing tables, keeps configured
results visible during reruns, uses a per-analysis DOM identifier and avoids
setting byte-identical HTML again. Errors clear/hide obsolete results.

The two extra entry points are maintained manually outside the upstream SPEC
registry. `tools/generate.py` does not overwrite them; `tools/sync-metadata.R`
now preserves their menu entries. The generator's registry comparison uses POSIX
paths consistently on Windows. No generated `.h.R` files are committed.

`R/cpDiagnostic.b.R` wraps the original bridge and supplies a Windows-only
embedded-interpreter override; original entries retain their macOS locator.
The shared Python runtime explicitly adds its trusted module directory for the
Windows `_pth` configuration and guards `signal.alarm` (the parent still enforces
its timeout). These are compatibility adaptations, not a migration to Pj.
No original analysis specifications or calculation algorithms are replaced.

## Validation

The earlier local laboratory was manually approved on Windows. This fork needs
its own verification; laboratory approval is not a macOS certification.
Run `tools/check-pj-comparison.R <installed-module-R-library>` in jamovi's
embedded R after building to check independent counts/exact intervals, both
Pj interpreters, changed cutoffs, missing values and error recovery. It requires
Pj installed beside the host and the selected Python dependencies.
Do not run it while installing/replacing the same module.
macOS compilation and interactive Apply/save/reopen must be verified by the
recipient on their Mac. No new macOS PASSED is claimed by this branch.

`tools/check-pj-routes.R <installed-module-R-library>` additionally compares
12 matched configurations of the two complete routes using jamovi Python.
It writes its timing CSV and report to a temporary directory; print or inspect
that directory when collecting evidence. Neither test installs or updates Pj.

### Fork validation, 26 October 2026 — Agente_Pj

Windows x64, jamovi 28.14, embedded R 4.6.0, embedded Python 3.14.5 and
System Python 3.14.7: isolated module build passed. Independent counts,
Clopper–Pearson intervals, both directions/criteria, automatic and changed
cutoffs, missing values, error recovery and unchanged global library paths
passed for both Pj interpreters. Twelve matched configurations of the original
processx route and Pj route produced identical native estimates and intervals.
Eight headless browser scenarios passed for D3 drag, numeric input, ROC/AUC
and Apply option messages. Metadata sync preserves the two comparison entries;
the upstream generated-source consistency check passed on Windows.
No new macOS or Linux build, GUI save/reopen or cancellation test is claimed.
