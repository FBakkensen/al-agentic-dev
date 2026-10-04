# Open code into modules

The refactor for a chosen candidate that is open code in an app whose `al-build.json` has `moduleGate.enabled` true. Every gate run is the Gate section's `/al-build` line, and each step ends green before the next starts.

1. **Characterization tests.** Write tests on the procedures to move, calling the open-code procedures directly: they are scaffolding with a planned end, retired in step 5. Write one test per behavior-bearing site and one test per event the procedures raise.
2. **Mutation set.** For each behavior-bearing site in those procedures, inject one compiling fault, get red, revert, confirm green, on the AL Runner gate. Every fault must turn a characterization test red. A surviving fault is closed by a stronger test, or the receipt gets a line naming the site and "deliberately unpinned" with its reason.
3. **Extraction.** Move the logic into new or existing modules (child namespaces), each tested through its root namespace by tests at the module's path. A new module's interface is a proposed Level 1 interface and goes to the user as Freeze says before the first move.
4. **Pure proxies.** Each old procedure keeps its signature and only delegates to the module's interface.
5. **Mutation handover.** Apply the step 2 faults again at the code's new home. Each is caught by the module's own tests; only then retire the characterization tests.
6. **Obsolete.** Once the refactor is completely finished, mark each proxy `[Obsolete('<replacement interface>', '<tag>')]`, naming the module interface that replaces it. The AL0432 warning at every caller is the list to switch.
7. **Callers switched.** Switch the callers to the module interface mechanically, warning by warning. A proxy only this app calls is deleted once its callers are switched. A proxy that dependents still call keeps its mark, so any new caller draws AL0432. Where the repository treats warnings as errors, steps 6 and 7 are one compilable step.

Event publishers that dependents subscribe to never become proxies and never move. Modules raise the same events, and the characterization tests pin each raise.
