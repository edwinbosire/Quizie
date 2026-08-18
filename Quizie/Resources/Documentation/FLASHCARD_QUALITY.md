# Flashcard quality contract

Quizie flashcards test one atomic fact. They are not multiple-choice questions with the options removed.

## Generated cards

The handbook flashcard prompt and both response validators require:

- one self-contained recall target per card;
- a direct question with no multiple-choice, negative, true/false, list, compound, or pronoun-dependent wording;
- the smallest sufficient answer, preferably one word, a date or year, a person's name, a place, an organisation, or a short named term;
- answers of eight words or fewer, with no lists, explanations, aliases, parenthetical expansions, relative clauses, or second facts;
- direct handbook support through valid source block IDs.

The backend rejects a non-conforming model response. The iOS client repeats the same checks before displaying or saving generated drafts.

## Bundled guide-card audit

The bundled guide deck is derived from 1,014 source quiz questions, but it no longer accepts every quiz question as a flashcard. `BundledFlashcardConverter` audits every source record and records each violation by question ID.

Current audited outcome:

- 582 atomic guide cards retained;
- 11 flagged cards safely repaired;
- 432 flagged cards excluded because no deterministic rewrite could guarantee one clear fact;
- 1,014 of 1,014 source records accounted for.

Safe repairs invert a choice-dependent fact into a direct subject-to-place or subject-to-description card, shorten an explicit alias/acronym to its minimal answer, or invert a distinctive biography so the person's name becomes the answer. Ambiguous multiple-answer, negative, true/false, verbose, list-based, vague, or option-dependent records are excluded rather than guessed at.

`ContentTaxonomyTaggingTests.guideCardsInheritTags` verifies the full-source accounting, exact audit totals, taxonomy coverage, and that every retained card satisfies `FlashcardRecallStyle`. `BundledFlashcardConverterTests` covers the individual repair and exclusion policies.
