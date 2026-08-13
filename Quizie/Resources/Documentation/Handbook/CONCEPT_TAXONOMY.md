# Concept Taxonomy V1

`concept-taxonomy.json` is derived metadata. `handbook.json` remains the factual source of truth.

## Generation

Run from the repository root:

```sh
python3 Scripts/generate_concept_taxonomy.py
```

The generator resolves every chapter, section and block reference against the current handbook before writing output. `Scripts/concept-taxonomy-heading-ids.json` freezes semantic concept and person entity IDs against stable handbook heading block IDs, so a display-title edit cannot silently rename a published ID.

`generatedAt` is fixed for deterministic V1 output and must not be used by runtime code. Change `taxonomyVersion` deliberately when the taxonomy changes and `handbookVersion` when references are regenerated for a new handbook content version.

## V1 normalization decisions

- No standalone source-taxonomy file accompanied the task. The 17 domains and required historical periods named in the supplied specification are the canonical seed; descendants are grounded in handbook headings and prose.
- The primary hierarchy is a tree. Cross-domain links are symmetric `relatedConceptIds` relationships.
- Magna Carta is canonical under medieval history and related to rule of law and democratic development. It is not duplicated in those domains.
- Named people and individual inventions are entities unless the handbook presents a broader testable learning concept.
- The Union Flag and National Anthem are identity concepts even though their source passages occur in history and constitution sections.
- Rule of law is canonical under law and justice and is related to fundamental British values rather than duplicated as a values child.
- The historical development of the Prime Minister and the modern government role are contextual specializations with distinct semantic IDs.

## V1 diagnostics

```text
Domains:                   17
Concepts:                 239
Leaf concepts:            187
Entities:                 100
Concept relationships:     17
Handbook sections used:    24
Handbook blocks linked:  1,001

Concepts without references:       0
Suspicious broad leaf concepts:    0
Handbook sections without coverage: 0
Duplicate aliases:                 0
```

The counts above describe taxonomy V1 and should be updated deliberately when its semantic version changes. The generator always prints current counts and warnings; those live diagnostics take precedence over this snapshot.

## Questions and flashcards

`questions.json` stores a `taxonomy` object on every question with a primary concept, all assigned concepts, and any explicitly named taxonomy entities. Its top-level `taxonomyVersion` must match this taxonomy. Regenerate and validate these assignments with:

```sh
python3 Scripts/tag_question_taxonomy.py
python3 Scripts/tag_question_taxonomy.py --check
```

The deterministic tagger uses exact taxonomy terms and handbook-block retrieval; distractor answers are not used for entity tagging. Bundled guide flashcards inherit their source question's taxonomy, and production loading rejects untagged bundled questions. AI-generated flashcards receive taxonomy locally from their cited handbook block IDs. Manually authored cards use exact concepts or entities, then a chapter root, with the values-and-citizenship root as the final fallback for uncategorised custom material. Custom-card taxonomy is persisted alongside source block IDs in SwiftData.
