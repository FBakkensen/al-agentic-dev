# arc42 v9.0-EN work-item template

This file is an adapted excerpt from the **arc42 Template Version 9.0-EN, July 2025**.

Created and maintained by Dr. Peter Hruschka, Dr. Gernot Starke, and contributors. See <https://arc42.org>.

Licensed under [Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/). Changes: only the Building Block View and Runtime View structures needed by this plugin are retained; Markdown levels and application notes are adapted for an Azure DevOps Original User Story.

Architecture content placed into this template remains the content owner's property.

## Building Block View

### Whitebox Overall System

***\<Overview Diagram\>***

Motivation

:   *\<text explanation\>*

Contained Building Blocks

:   *\<Description of contained building blocks as black boxes\>*

Important Interfaces

:   *\<Description of important interfaces\>*

#### \<Name black box\>

*\<Purpose/Responsibility\>*

*\<Interface(s)\>*

*\<(Optional) Quality/Performance Characteristics\>*

*\<(Optional) Directory/File Location\>*

*\<(Optional) Fulfilled Requirements\>*

*\<(Optional) Open Issues/Problems/Risks\>*

Repeat the black box section for every important contained building block. Describe an interface separately only when its contract needs more than the owning black box.

### Level 2

#### White Box *\<selected Level 1 building block\>*

***\<Overview Diagram\>***

Motivation

:   *\<reason for this proven internal decomposition\>*

Contained Building Blocks

:   *\<black boxes for stable internal building blocks\>*

Important Interfaces

:   *\<important internal and boundary interfaces\>*

Repeat the black box template above for every important internal building block.

## Runtime View

### \<Runtime Scenario\>

- *\<runtime diagram or textual description of the scenario\>*
- *\<notable aspects of the interactions between the depicted building block instances\>*

Repeat only for architecturally relevant use cases, critical external interfaces, operational behavior, or error scenarios.

## Application in this plugin

- Level 1 is written before implementation and records intended module contracts.
- Runtime View is written only when interaction order, ownership, or a transaction boundary needs explanation.
- Level 2 is written after implementation and only for relevant, stable internal structure.
- An implementation change map is an overlay on these Building Block views, not another arc42 heading.
- One affected Level 1 module uses a Level 2 white box. Several affected modules use a Level 1 impact overview plus the Level 2 white boxes needed to explain internal object relations.
- A change overlay includes every changed production AL object, immediate unchanged collaborators needed for context, and changed tests in a separate Proof group.
- Overlay nodes are marked `Added`, `Changed`, `Existing`, or `Removed`; edges name the exact procedure, event, interface implementation, or Read/Insert/Modify relation.
- The executable-item receipt and comment keep the change overlay. The Original User Story keeps only stable current-state Level 2 content without change markers.
- The local HTML and Azure DevOps Original User Story use these headings and field order without synonyms.
