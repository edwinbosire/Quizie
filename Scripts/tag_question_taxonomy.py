#!/usr/bin/env python3
"""Deterministically tag Quizie's bundled questions with the concept taxonomy.

The tagger uses only the bundled handbook and taxonomy. It combines exact taxonomy
terms with BM25-style handbook retrieval, then records the most specific concepts
and explicitly named entities for each question.

Run from the repository root:

    python3 Scripts/tag_question_taxonomy.py
    python3 Scripts/tag_question_taxonomy.py --check
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
QUESTIONS_PATH = ROOT / "Quizie/Resources/Data/questions.json"
HANDBOOK_PATH = ROOT / "Quizie/Resources/Data/handbook.json"
TAXONOMY_PATH = ROOT / "Quizie/Resources/Data/concept-taxonomy.json"
TOKEN_PATTERN = re.compile(r"[a-z0-9]+")
STOP_WORDS = {
    "a", "about", "after", "all", "also", "an", "and", "are", "as", "at", "be", "been", "before", "being", "between", "both", "but", "by", "can", "called", "did", "do", "does", "during", "each", "for", "from", "had", "has", "have", "how", "in", "into", "is", "it", "its", "known", "many", "more", "most", "not", "of", "on", "one", "or", "other", "own", "part", "that", "the", "their", "there", "these", "they", "this", "those", "to", "two", "uk", "united", "was", "were", "what", "when", "where", "which", "who", "why", "with", "would",
}
CATEGORY_FALLBACKS = {
    "1": "uk-values-and-citizenship",
    "2": "uk-identity-and-geography",
    "3": "history",
    "4": "uk-society",
    "5": "government",
}
CURATED_TERM_CONCEPTS = {
    "act of union": "history.formation-of-great-britain",
    "boxing day": "customs-and-traditions.main-christian-festivals",
    "capital of uk": "uk-identity-and-geography.countries",
    "capital of wales": "uk-identity-and-geography.countries",
    "cenotaph": "customs-and-traditions.remembrance-day",
    "christmas": "customs-and-traditions.main-christian-festivals",
    "easter": "customs-and-traditions.main-christian-festivals",
    "halloween": "customs-and-traditions.other-festivals-and-traditions",
    "head of state": "democracy-and-constitution.constitutional-institutions.monarchy",
    "lent": "customs-and-traditions.main-christian-festivals",
    "music festival": "arts-and-culture.music",
    "part of the uk": "uk-identity-and-geography.countries",
    "paralymp": "sport.notable-british-sportsmen-and-women",
    "queen elizabeth ii": "democracy-and-constitution.constitutional-institutions.monarchy",
    "roman army": "history.roman-britain.romans",
    "st david": "religion.patron-saints-days",
    "st george": "religion.patron-saints-days",
    "st patrick": "religion.patron-saints-days",
    "st andrew": "religion.patron-saints-days",
    "valentine": "customs-and-traditions.other-festivals-and-traditions",
}


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii").lower()
    value = re.sub(r"\bwwii\b|\bworld war (?:two|2)\b", "second world war", value)
    value = re.sub(r"\bwwi\b|\bworld war (?:one|1)\b", "first world war", value)
    value = re.sub(r"\beec\b", "european economic community", value)
    return " ".join(TOKEN_PATTERN.findall(value))


def stem(token: str) -> str:
    if len(token) > 5 and token.endswith("ies"):
        return token[:-3] + "y"
    if len(token) > 5 and token.endswith("ing"):
        return token[:-3]
    if len(token) > 4 and token.endswith("ed"):
        return token[:-2]
    if len(token) > 4 and token.endswith(("ches", "shes", "sses", "xes", "zes")):
        return token[:-2]
    if len(token) > 3 and token.endswith("s") and not token.endswith("ss"):
        return token[:-1]
    return token


def tokens(value: str) -> list[str]:
    return [stem(token) for token in TOKEN_PATTERN.findall(normalize(value)) if token not in STOP_WORDS]


def block_text(block: dict) -> str:
    if block.get("text"):
        return block["text"]
    if block.get("items"):
        return "; ".join(block["items"])
    values = list(block.get("headers", [])) + [cell for row in block.get("rows", []) for cell in row]
    return "; ".join(values)


def handbook_documents(handbook: dict) -> list[dict]:
    documents = []
    for chapter in handbook["chapters"]:
        for section in chapter["sections"]:
            heading_path = []
            for block in section["content"]:
                text = block_text(block)
                if block.get("type") == "heading":
                    level = int(block.get("level", 2))
                    heading_path = heading_path[:max(0, level - 2)] + [text]
                context = " ".join([section["title"], *heading_path, text])
                documents.append({"id": block["id"], "tokens": tokens(context)})
            if section.get("facts") and section.get("facts_id"):
                context = " ".join([section["title"], *heading_path, *section["facts"]])
                documents.append({"id": section["facts_id"], "tokens": tokens(context)})
    return documents


class HandbookIndex:
    def __init__(self, documents: list[dict]):
        self.documents = documents
        self.term_frequencies = [Counter(document["tokens"]) for document in documents]
        self.lengths = [sum(frequencies.values()) for frequencies in self.term_frequencies]
        self.average_length = sum(self.lengths) / max(1, len(self.lengths))
        document_frequency = Counter()
        for frequencies in self.term_frequencies:
            document_frequency.update(frequencies.keys())
        count = len(documents)
        self.idf = {term: math.log(1 + (count - frequency + 0.5) / (frequency + 0.5)) for term, frequency in document_frequency.items()}

    def search(self, query: list[str], limit: int = 8) -> list[tuple[str, float]]:
        query_terms = Counter(query)
        scores = []
        for index, frequencies in enumerate(self.term_frequencies):
            score = 0.0
            length = self.lengths[index]
            for term, query_frequency in query_terms.items():
                frequency = frequencies.get(term, 0)
                if not frequency:
                    continue
                denominator = frequency + 1.2 * (0.25 + 0.75 * length / self.average_length)
                score += self.idf.get(term, 0) * frequency * 2.2 / denominator * min(query_frequency, 3)
            if score:
                scores.append((self.documents[index]["id"], score))
        return sorted(scores, key=lambda item: (-item[1], item[0]))[:limit]


class TaxonomyTagger:
    def __init__(self, taxonomy: dict):
        self.taxonomy = taxonomy
        self.concepts = {concept["id"]: concept for concept in taxonomy["concepts"]}
        self.entities = {entity["id"]: entity for entity in taxonomy["entities"]}
        self.depths = {concept_id: concept_id.count(".") for concept_id in self.concepts}
        self.concepts_by_block = defaultdict(set)
        for concept in taxonomy["concepts"]:
            for reference in concept["handbookReferences"]:
                for block_id in reference["blockIds"]:
                    self.concepts_by_block[block_id].add(concept["id"])
        self.entity_terms = self._entity_terms()
        self.concept_terms = self._concept_terms()

    def _concept_terms(self) -> list[tuple[str, str, int]]:
        result = []
        for concept in self.taxonomy["concepts"]:
            if concept["parentId"] is None:
                continue
            terms = [concept["displayName"], *concept["aliases"]]
            if concept.get("taggingHints"):
                terms += concept["taggingHints"]["includeTerms"]
            for term in dict.fromkeys(terms):
                normalized = " ".join(tokens(term))
                meaningful = tokens(term)
                if len(normalized) >= 4 and len(meaningful) >= 2 and normalized not in {"great britain", "united kingdom"}:
                    result.append((normalized, concept["id"], len(meaningful)))
        return sorted(set(result), key=lambda item: (-len(item[0]), item[1]))

    def _entity_terms(self) -> list[tuple[str, str, int]]:
        result = []
        for entity in self.taxonomy["entities"]:
            for term in dict.fromkeys([entity["displayName"], *entity["aliases"]]):
                normalized = " ".join(tokens(term))
                if len(normalized) >= 4:
                    result.append((normalized, entity["id"], len(tokens(term))))
        return sorted(set(result), key=lambda item: (-len(item[0]), item[1]))

    def tags(self, question: dict, matches: list[tuple[str, float]]) -> dict:
        correct_answers = [question["choices"][int(index)] for index in question["correct"]]
        raw_core_text = normalize(" ".join([question["question"], *correct_answers]))
        question_text = " ".join(tokens(question["question"]))
        answer_text = " ".join(tokens(" ".join(correct_answers)))
        core_text = " ".join([question_text, answer_text])
        scores = defaultdict(float)
        direct_concepts = set()

        for term, concept_id in CURATED_TERM_CONCEPTS.items():
            if term == "paralymp" and term in raw_core_text or term != "paralymp" and self._contains_phrase(raw_core_text, term):
                scores[concept_id] += 60
                direct_concepts.add(concept_id)

        for rank, (block_id, score) in enumerate(matches):
            decay = 1 / (1 + rank * 0.35)
            block_concepts = self._most_specific(self.concepts_by_block.get(block_id, set()))
            for concept_id in block_concepts:
                evidence = score * decay * (1 + self.depths[concept_id] * 0.08)
                scores[concept_id] = max(scores[concept_id], evidence)

        for term, concept_id, term_count in self.concept_terms:
            if self._contains_phrase(question_text, term):
                scores[concept_id] += 24 + term_count * 5
                direct_concepts.add(concept_id)
            elif self._contains_phrase(answer_text, term):
                scores[concept_id] += (4 if " not " in f" {normalize(question['question'])} " else 16) + term_count * 3
                direct_concepts.add(concept_id)

        entity_ids = []
        for term, entity_id, term_count in self.entity_terms:
            if self._contains_phrase(core_text, term):
                entity_ids.append(entity_id)
                for concept_id in self.entities[entity_id]["relatedConceptIds"]:
                    scores[concept_id] += 14
                    direct_concepts.add(concept_id)

        selection_scores = {concept_id: scores[concept_id] for concept_id in direct_concepts} if direct_concepts else scores
        concept_ids = self._select_concepts(selection_scores, question["category"])
        primary_concept_id = concept_ids[0]
        entity_ids = sorted(set(entity_ids), key=lambda entity_id: list(self.entities).index(entity_id))
        return {"primaryConceptId": primary_concept_id, "conceptIds": concept_ids, "entityIds": entity_ids}

    def _select_concepts(self, scores: dict[str, float], category: str) -> list[str]:
        candidates = [(concept_id, score) for concept_id, score in scores.items() if self.concepts[concept_id]["parentId"] is not None]
        candidates.sort(key=lambda item: (-item[1], -self.depths[item[0]], item[0]))
        if not candidates:
            return [CATEGORY_FALLBACKS[category]]
        primary_id, primary_score = candidates[0]
        selected = [primary_id]
        for concept_id, score in candidates[1:]:
            if len(selected) == 3 or score < primary_score * 0.88:
                break
            if all(not self._related_by_ancestry(concept_id, existing) for existing in selected):
                selected.append(concept_id)
        return selected

    def _most_specific(self, concept_ids: set[str]) -> set[str]:
        return {concept_id for concept_id in concept_ids if not any(other != concept_id and self._is_ancestor(concept_id, other) for other in concept_ids)}

    def _related_by_ancestry(self, left: str, right: str) -> bool:
        return self._is_ancestor(left, right) or self._is_ancestor(right, left)

    def _is_ancestor(self, ancestor: str, descendant: str) -> bool:
        current = self.concepts[descendant]["parentId"]
        while current:
            if current == ancestor:
                return True
            current = self.concepts[current]["parentId"]
        return False

    @staticmethod
    def _contains_phrase(text: str, phrase: str) -> bool:
        return f" {phrase} " in f" {text} "


def question_query(question: dict) -> list[str]:
    correct_answers = [question["choices"][int(index)] for index in question["correct"]]
    return tokens(" ".join([question["question"], question["question"], *correct_answers, *correct_answers]))


def validate(document: dict, taxonomy: dict) -> list[str]:
    errors = []
    concept_ids = {concept["id"] for concept in taxonomy["concepts"]}
    entity_ids = {entity["id"] for entity in taxonomy["entities"]}
    if document.get("schemaVersion") != 1:
        errors.append("questions.json schemaVersion must be 1")
    if document.get("taxonomyVersion") != taxonomy["taxonomyVersion"]:
        errors.append("questions.json taxonomyVersion does not match concept-taxonomy.json")
    for question in document.get("data", []):
        question_id = question.get("question_id", "<missing>")
        tags = question.get("taxonomy")
        if not tags:
            errors.append(f"Question {question_id} has no taxonomy")
            continue
        if not tags.get("conceptIds"):
            errors.append(f"Question {question_id} has no concept IDs")
        if tags.get("primaryConceptId") not in tags.get("conceptIds", []):
            errors.append(f"Question {question_id} primary concept is not in conceptIds")
        for concept_id in tags.get("conceptIds", []):
            if concept_id not in concept_ids:
                errors.append(f"Question {question_id} references missing concept {concept_id}")
        for entity_id in tags.get("entityIds", []):
            if entity_id not in entity_ids:
                errors.append(f"Question {question_id} references missing entity {entity_id}")
    return errors


def generate() -> tuple[dict, dict]:
    questions = json.loads(QUESTIONS_PATH.read_text(encoding="utf-8"))
    handbook = json.loads(HANDBOOK_PATH.read_text(encoding="utf-8"))
    taxonomy = json.loads(TAXONOMY_PATH.read_text(encoding="utf-8"))
    index = HandbookIndex(handbook_documents(handbook))
    tagger = TaxonomyTagger(taxonomy)
    for question in questions["data"]:
        question["taxonomy"] = tagger.tags(question, index.search(question_query(question)))
    questions = {"schemaVersion": 1, "taxonomyVersion": taxonomy["taxonomyVersion"], "data": questions["data"]}
    return questions, taxonomy


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Validate that questions.json is current without rewriting it")
    args = parser.parse_args()
    document, taxonomy = generate()
    errors = validate(document, taxonomy)
    if errors:
        print("Question taxonomy validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    encoded = json.dumps(document, indent=4, ensure_ascii=False) + "\n"
    current = QUESTIONS_PATH.read_text(encoding="utf-8")
    if args.check:
        if current != encoded:
            print("questions.json taxonomy tags are stale; run Scripts/tag_question_taxonomy.py", file=sys.stderr)
            return 1
    else:
        QUESTIONS_PATH.write_text(encoded, encoding="utf-8")
    concept_counts = Counter(tag for question in document["data"] for tag in question["taxonomy"]["conceptIds"])
    entity_count = sum(len(question["taxonomy"]["entityIds"]) for question in document["data"])
    print(f"Tagged {len(document['data'])} questions with {len(concept_counts)} concepts and {entity_count} entity references.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
