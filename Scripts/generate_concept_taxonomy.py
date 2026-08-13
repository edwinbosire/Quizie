#!/usr/bin/env python3
"""Generate and validate Quizie's deterministic Life in the UK concept taxonomy.

The handbook is the factual source. The concept seeds and normalization decisions in
this file are derived only from handbook.json and the taxonomy specification supplied
for the project. Run from the repository root with:

    python3 Scripts/generate_concept_taxonomy.py
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HANDBOOK_PATH = ROOT / "Quizie/Resources/Data/handbook.json"
OUTPUT_PATH = ROOT / "Quizie/Resources/Data/concept-taxonomy.json"
HEADING_IDS_PATH = ROOT / "Scripts/concept-taxonomy-heading-ids.json"
GENERATED_AT = "2026-08-13T00:00:00Z"
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*(?:\.[a-z0-9]+(?:-[a-z0-9]+)*)*$")
PERSON_HEADING = re.compile(r"^(.+?)\s*\((?:c\.\s*)?\d{3,4}[^)]*\)$")
SKIPPED_HEADING_IDS = {"section_01_03_block_010"}


DOMAIN_SPECS = [
    ("uk-values-and-citizenship", "UK Values and Citizenship", "The values, freedoms, responsibilities and citizenship knowledge presented in the handbook.", ["section_01_01", "section_01_02", "section_01_03"]),
    ("uk-identity-and-geography", "UK Identity and Geography", "The countries, names, symbols and geographical identity of the United Kingdom.", ["section_02_01", "section_04_01"]),
    ("history", "British History", "The periods, events and developments in British history covered by the handbook.", ["section_03_01", "section_03_02", "section_03_03", "section_03_04", "section_03_05", "section_03_06"]),
    ("science-and-invention", "British Science and Invention", "Scientific discoveries, engineering achievements and inventions described in the handbook.", ["section_03_03", "section_03_04", "section_03_05", "section_03_06"]),
    ("arts-and-culture", "Arts and Culture", "British music, theatre, art, architecture, design and literature covered by the handbook.", ["section_04_05"]),
    ("customs-and-traditions", "Customs and Traditions", "Festivals, commemorations, holidays and traditions observed in the UK.", ["section_04_02", "section_04_03"]),
    ("leisure-and-everyday-culture", "Leisure and Everyday Culture", "Popular leisure activities, food, media and everyday cultural practices in the UK.", ["section_04_06"]),
    ("places-and-landmarks", "Places and Landmarks", "Important UK places, landscapes and landmarks described in the handbook.", ["section_04_07"]),
    ("religion", "Religion in the UK", "Religious diversity, churches and faith communities in the United Kingdom.", ["section_04_02"]),
    ("sport", "Sport", "Sports, competitions and sporting traditions described in the handbook.", ["section_04_04"]),
    ("uk-society", "UK Society Today", "The population, diversity, equality and social characteristics of the modern UK.", ["section_04_01"]),
    ("democracy-and-constitution", "British Democracy and Constitution", "The development and institutions of British democracy and the constitution.", ["section_05_01", "section_05_02"]),
    ("government", "Government", "The institutions, roles, elections and administrations through which the UK is governed.", ["section_05_02", "section_05_03"]),
    ("law-and-justice", "Law and Justice", "The rule of law, legal duties, policing, courts and access to justice in the UK.", ["section_05_05", "section_05_06"]),
    ("taxation-and-responsibilities", "Taxation and Everyday Responsibilities", "Tax, National Insurance, driving and other everyday legal responsibilities.", ["section_05_06"]),
    ("international-relations", "UK International Relations", "The United Kingdom's relationships with international institutions described in the handbook.", ["section_05_04"]),
    ("community-and-civic-participation", "Community and Civic Participation", "Ways residents can participate in civic, political, voluntary and environmental life.", ["section_05_07"]),
]


ALIASES = {
    "uk-values-and-citizenship.fundamental-british-values": ["Fundamental principles of British life", "British values"],
    "uk-values-and-citizenship.citizenship-pledge": ["Citizenship ceremony pledge"],
    "uk-identity-and-geography.united-kingdom": ["UK", "United Kingdom of Great Britain and Northern Ireland"],
    "uk-identity-and-geography.great-britain": ["Britain"],
    "uk-identity-and-geography.union-flag": ["Union Jack"],
    "history.norman-britain.norman-conquest": ["Norman invasion"],
    "history.norman-britain.battle-of-hastings": ["Hastings"],
    "history.middle-ages": ["Medieval period", "Medieval Britain"],
    "history.middle-ages.magna-carta": ["Great Charter"],
    "history.stuarts.english-civil-war": ["Civil War"],
    "history.stuarts.english-republic": ["Commonwealth period"],
    "history.formation-of-great-britain": ["Formation of Britain"],
    "science-and-invention.twentieth-century-inventions": ["20th-century British inventions"],
    "customs-and-traditions.bonfire-night": ["5 November"],
    "government.parliament.house-of-commons": ["Commons", "The Commons"],
    "government.devolved-administrations.welsh-government": ["Welsh Assembly", "National Assembly for Wales", "Senedd"],
    "government.devolved-administrations.northern-ireland-assembly": ["Northern Ireland Assembly", "Stormont"],
    "international-relations.european-union": ["EU"],
    "international-relations.north-atlantic-treaty-organization": ["NATO"],
    "international-relations.united-nations": ["UN"],
}


PERSON_ALIASES = {
    "Winston Churchill": ["Churchill"],
    "William Shakespeare": ["Shakespeare"],
    "Isaac Newton": ["Sir Isaac Newton", "Newton"],
    "Florence Nightingale": ["Nightingale"],
    "Alexander Fleming": ["Fleming"],
    "Margaret Thatcher": ["Mrs Thatcher", "Thatcher"],
    "Emmeline Pankhurst": ["Pankhurst"],
    "Isambard Kingdom Brunel": ["Brunel"],
    "Robert Burns": ["Burns"],
    "Rudyard Kipling": ["Kipling"],
    "Roald Dahl": ["Dahl"],
}

PERSON_RELATED_CONCEPTS = {
    "William Shakespeare": ["arts-and-culture.literature"],
    "Isaac Newton": ["science-and-invention.early-modern-science"],
    "Richard Arkwright": ["science-and-invention.industrial-engineering"],
    "Sake Dean Mahomet": ["science-and-invention.industrial-engineering"],
    "Isambard Kingdom Brunel": ["science-and-invention.industrial-engineering"],
    "Florence Nightingale": ["science-and-invention.medical-advances"],
    "Alexander Fleming": ["science-and-invention.medical-advances"],
    "Robert Burns": ["arts-and-culture.literature"],
    "Rudyard Kipling": ["arts-and-culture.literature"],
    "Dylan Thomas": ["arts-and-culture.literature"],
    "Roald Dahl": ["arts-and-culture.literature"],
    "Mary Peters": ["sport.notable-british-sportsmen-and-women"],
}


ENTITY_TYPE_ORDER = ["person", "date", "event", "place", "institution", "law", "document", "organisation", "invention", "work"]


def slugify(value: str) -> str:
    value = value.replace("&", " and ").replace("’", "'")
    value = re.sub(r"\([^)]*\d[^)]*\)", "", value)
    value = re.sub(r"^(the|some)\s+", "", value.strip(), flags=re.IGNORECASE)
    value = value.lower().replace("'s", "s")
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value


def clean_display_name(value: str) -> str:
    return re.sub(r"\s*\((?:c\.\s*)?\d{3,4}[^)]*\)\s*$", "", value).strip()


def plain_text(block: dict) -> str:
    if block.get("text"):
        return block["text"]
    if block.get("items"):
        return "; ".join(block["items"])
    if block.get("headers") or block.get("rows"):
        values = list(block.get("headers", [])) + [cell for row in block.get("rows", []) for cell in row]
        return "; ".join(values)
    return ""


def concise_description(display_name: str, blocks: list[dict]) -> str:
    text = next((plain_text(block) for block in blocks if block.get("type") != "heading" and plain_text(block).strip()), "")
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return f"Handbook knowledge relating to {display_name}."
    sentence = re.split(r"(?<=[.!?])\s+", text, maxsplit=1)[0]
    if len(sentence) > 220:
        sentence = sentence[:217].rsplit(" ", 1)[0] + "…"
    return sentence


class TaxonomyBuilder:
    def __init__(self, handbook: dict):
        self.handbook = handbook
        heading_ids = json.loads(HEADING_IDS_PATH.read_text(encoding="utf-8"))
        self.concept_ids_by_heading = heading_ids["conceptIdsByHeadingBlockId"]
        self.person_ids_by_heading = heading_ids["personEntityIdsByHeadingBlockId"]
        self.chapters = {chapter["id"]: chapter for chapter in handbook["chapters"]}
        self.sections = {}
        self.section_chapters = {}
        self.blocks = {}
        self.block_sections = {}
        for chapter in handbook["chapters"]:
            for section in chapter["sections"]:
                self.sections[section["id"]] = section
                self.section_chapters[section["id"]] = chapter["id"]
                for block in section["content"]:
                    self.blocks[block["id"]] = block
                    self.block_sections[block["id"]] = section["id"]
                if section.get("facts") and section.get("facts_id"):
                    fact_block = {"id": section["facts_id"], "type": "facts", "items": section["facts"]}
                    self.blocks[fact_block["id"]] = fact_block
                    self.block_sections[fact_block["id"]] = section["id"]
        concept_heading_ids = {
            block["id"] for section in self.sections.values() for block in section["content"]
            if block.get("type") == "heading" and not PERSON_HEADING.match(block.get("text", "")) and block["id"] not in SKIPPED_HEADING_IDS
        }
        person_heading_ids = {
            block["id"] for section in self.sections.values() for block in section["content"]
            if block.get("type") == "heading" and PERSON_HEADING.match(block.get("text", ""))
        }
        if set(self.concept_ids_by_heading) != concept_heading_ids:
            raise ValueError("Frozen concept heading IDs do not exactly match handbook headings")
        if set(self.person_ids_by_heading) != person_heading_ids:
            raise ValueError("Frozen person heading IDs do not exactly match handbook person headings")
        self.concepts = {}
        self.concept_order = []
        self.entities = {}
        self.relationship_pairs = set()
        self.ambiguities = []

    def section_reference(self, section_id: str) -> dict:
        return {"chapterId": self.section_chapters[section_id], "sectionId": section_id, "blockIds": []}

    def range_reference(self, section_id: str, start_id: str | None = None, end_exclusive_id: str | None = None) -> dict:
        ids = [block["id"] for block in self.sections[section_id]["content"]]
        if self.sections[section_id].get("facts") and self.sections[section_id].get("facts_id"):
            ids.append(self.sections[section_id]["facts_id"])
        start = ids.index(start_id) if start_id else 0
        end = ids.index(end_exclusive_id) if end_exclusive_id else len(ids)
        return {"chapterId": self.section_chapters[section_id], "sectionId": section_id, "blockIds": ids[start:end]}

    def blocks_for_reference(self, reference: dict) -> list[dict]:
        return [self.blocks[block_id] for block_id in reference["blockIds"]]

    def add_concept(self, concept_id: str, display_name: str, description: str, parent_id: str | None, references: list[dict], weight: float, aliases: list[str] | None = None, tagging_terms: list[str] | None = None) -> dict:
        if concept_id in self.concepts:
            raise ValueError(f"Duplicate concept ID: {concept_id}")
        domain_id = concept_id.split(".", 1)[0]
        tier = "critical" if weight >= 0.9 else "high" if weight >= 0.7 else "medium" if weight >= 0.4 else "low"
        aliases = list(dict.fromkeys(aliases or ALIASES.get(concept_id, [])))
        include_terms = list(dict.fromkeys(tagging_terms or ([display_name] + aliases if parent_id and len(display_name) >= 4 else [])))
        concept = {
            "id": concept_id,
            "slug": concept_id.rsplit(".", 1)[-1],
            "displayName": display_name,
            "description": description,
            "domainId": domain_id,
            "parentId": parent_id,
            "childIds": [],
            "aliases": aliases,
            "relatedConceptIds": [],
            "handbookReferences": references,
            "entityIds": [],
            "importance": {
                "weight": weight,
                "tier": tier,
                "rationale": "Initial product heuristic based on handbook prominence and conceptual centrality."
            }
        }
        if include_terms:
            concept["taggingHints"] = {"includeTerms": include_terms, "excludeTerms": []}
        self.concepts[concept_id] = concept
        self.concept_order.append(concept_id)
        return concept

    def add_or_merge_heading(self, concept_id: str, display_name: str, parent_id: str, reference: dict, level: int) -> str:
        if concept_id in self.concepts:
            if reference not in self.concepts[concept_id]["handbookReferences"]:
                self.concepts[concept_id]["handbookReferences"].append(reference)
            return concept_id
        blocks = self.blocks_for_reference(reference)
        weight = 0.74 if level <= 2 else 0.62 if level == 3 else 0.48
        important_terms = ("parliament", "election", "constitution", "law", "world war", "industrial revolution", "british empire")
        if any(term in display_name.lower() for term in important_terms):
            weight = max(weight, 0.78)
        self.add_concept(concept_id, display_name, concise_description(display_name, blocks), parent_id, [reference], weight)
        return concept_id

    def relate(self, left: str, right: str) -> None:
        if left != right:
            self.relationship_pairs.add(tuple(sorted((left, right))))

    def add_entity(self, entity_id: str, entity_type: str, display_name: str, aliases: list[str], references: list[dict], preferred_concepts: list[str] | None = None) -> None:
        if entity_id in self.entities:
            entity = self.entities[entity_id]
            entity["aliases"] = list(dict.fromkeys(entity["aliases"] + aliases))
            for reference in references:
                if reference not in entity["handbookReferences"]:
                    entity["handbookReferences"].append(reference)
            entity["_preferredConceptIds"] = list(dict.fromkeys(entity["_preferredConceptIds"] + (preferred_concepts or [])))
            return
        self.entities[entity_id] = {
            "id": entity_id,
            "type": entity_type,
            "displayName": display_name,
            "aliases": aliases,
            "relatedConceptIds": [],
            "handbookReferences": references,
            "_preferredConceptIds": preferred_concepts or []
        }

    def fixed_concepts(self) -> None:
        root_weight = {
            "uk-values-and-citizenship": 0.96, "history": 0.92, "democracy-and-constitution": 0.95,
            "government": 0.96, "law-and-justice": 0.94, "uk-identity-and-geography": 0.86
        }
        for concept_id, display_name, description, section_ids in DOMAIN_SPECS:
            self.add_concept(concept_id, display_name, description, None, [self.section_reference(section_id) for section_id in section_ids], root_weight.get(concept_id, 0.78))

        def add(concept_id: str, display_name: str, parent_id: str, description: str, refs: list[tuple[str, str | None, str | None]], weight: float, tagging_terms: list[str] | None = None):
            references = [self.range_reference(section_id, start_id, end_id) for section_id, start_id, end_id in refs]
            self.add_concept(concept_id, display_name, description, parent_id, references, weight, tagging_terms=tagging_terms)

        # Values, citizenship and test knowledge without handbook headings.
        add("uk-values-and-citizenship.fundamental-british-values", "Fundamental British Values", "uk-values-and-citizenship", "The fundamental values and principles expected to be respected and supported in British society.", [("section_01_01", "section_01_01_block_001", "section_01_01_block_006")], 0.96)
        for slug, name in [("democracy", "Democracy"), ("individual-liberty", "Individual Liberty"), ("tolerance", "Tolerance of Different Faiths and Beliefs"), ("community-participation", "Participation in Community Life")]:
            add(f"uk-values-and-citizenship.fundamental-british-values.{slug}", name, "uk-values-and-citizenship.fundamental-british-values", f"{name} as a fundamental principle of British life.", [("section_01_01", "section_01_01_block_002", "section_01_01_block_004")], 0.88)
        add("uk-values-and-citizenship.citizenship-pledge", "Citizenship Pledge", "uk-values-and-citizenship", "The pledge made by new citizens to uphold UK values, rights, freedoms, laws and duties.", [("section_01_01", "section_01_01_block_004", "section_01_01_block_006")], 0.76)
        add("uk-values-and-citizenship.responsibilities", "Responsibilities of UK Residents", "uk-values-and-citizenship", "Responsibilities shared by people living in the UK.", [("section_01_01", "section_01_01_block_006", "section_01_01_block_009")], 0.88)
        add("uk-values-and-citizenship.rights-and-freedoms", "Rights and Freedoms", "uk-values-and-citizenship", "Freedoms and rights offered to people living in the UK.", [("section_01_01", "section_01_01_block_009", None)], 0.9)
        add("uk-values-and-citizenship.permanent-residence-and-citizenship", "Permanent Residence and Citizenship", "uk-values-and-citizenship", "Handbook requirements and routes for applying for permanent residence or citizenship.", [("section_01_02", None, None)], 0.68)
        add("uk-values-and-citizenship.life-in-the-uk-test", "Life in the UK Test", "uk-values-and-citizenship", "The format, booking and preparation information for the Life in the UK test.", [("section_01_03", None, None)], 0.64)

        # UK identity concepts in the unheaded chapter and symbol references elsewhere.
        add("uk-identity-and-geography.united-kingdom", "United Kingdom", "uk-identity-and-geography", "The four countries and official name of the United Kingdom.", [("section_02_01", "section_02_01_block_001", "section_02_01_block_003")], 0.9)
        add("uk-identity-and-geography.great-britain", "Great Britain", "uk-identity-and-geography", "The handbook distinction between Great Britain and the United Kingdom.", [("section_02_01", "section_02_01_block_002", "section_02_01_block_003")], 0.86)
        add("uk-identity-and-geography.countries", "Countries of the UK", "uk-identity-and-geography", "England, Scotland, Wales and Northern Ireland as the constituent countries of the UK.", [("section_02_01", "section_02_01_block_001", "section_02_01_block_002"), ("section_04_01", "section_04_01_block_002", "section_04_01_block_004")], 0.88)
        add("uk-identity-and-geography.crown-dependencies", "Crown Dependencies", "uk-identity-and-geography", "The islands linked with the UK that have their own governments and are not part of the UK.", [("section_02_01", "section_02_01_block_003", "section_02_01_block_004")], 0.68)
        add("uk-identity-and-geography.british-overseas-territories", "British Overseas Territories", "uk-identity-and-geography", "Territories linked to the UK but not forming part of it.", [("section_02_01", "section_02_01_block_003", "section_02_01_block_004")], 0.72)
        add("uk-identity-and-geography.union-flag", "Union Flag", "uk-identity-and-geography", "The composition and national associations of the United Kingdom's flag.", [("section_03_04", "section_03_04_block_038", "section_03_04_block_045")], 0.78)
        add("uk-identity-and-geography.national-anthem", "National Anthem", "uk-identity-and-geography", "The UK national anthem and the occasions on which it is played.", [("section_05_02", "section_05_02_block_019", "section_05_02_block_023")], 0.58)

        # Required stable historical period tree.
        history_periods = [
            ("prehistoric-britain", "Prehistoric Britain", "section_03_01", None, "section_03_01_block_004", 0.72),
            ("roman-britain", "Roman Britain", "section_03_01", "section_03_01_block_004", "section_03_01_block_008", 0.82),
            ("anglo-saxon-britain", "Anglo-Saxon Britain", "section_03_01", "section_03_01_block_008", "section_03_01_block_011", 0.78),
            ("viking-britain", "Viking Britain", "section_03_01", "section_03_01_block_011", "section_03_01_block_014", 0.78),
            ("norman-britain", "Norman Britain", "section_03_01", "section_03_01_block_014", None, 0.9),
            ("middle-ages", "The Middle Ages", "section_03_02", None, None, 0.86),
            ("tudors", "The Tudors", "section_03_03", None, "section_03_03_block_032", 0.88),
            ("stuarts", "The Stuarts", "section_03_03", "section_03_03_block_032", None, 0.88),
            ("formation-of-great-britain", "Formation of Great Britain", "section_03_04", None, "section_03_04_block_016", 0.82),
            ("enlightenment", "The Enlightenment", "section_03_04", "section_03_04_block_016", "section_03_04_block_018", 0.7),
            ("industrial-revolution", "The Industrial Revolution", "section_03_04", "section_03_04_block_018", "section_03_04_block_030", 0.9),
            ("british-empire", "The British Empire", "section_03_04", "section_03_04_block_030", "section_03_04_block_045", 0.86),
            ("victorian-britain", "Victorian Britain", "section_03_04", "section_03_04_block_045", "section_03_04_block_064", 0.82),
            ("development-of-voting-rights", "Development of Voting Rights", "section_03_04", "section_03_04_block_064", "section_03_04_block_071", 0.84),
            ("first-world-war", "The First World War", "section_03_05", "section_03_05_block_001", "section_03_05_block_006", 0.92),
            ("interwar-period", "The Inter-war Period", "section_03_05", "section_03_05_block_006", "section_03_05_block_011", 0.72),
            ("second-world-war", "The Second World War", "section_03_05", "section_03_05_block_011", None, 0.94),
            ("britain-since-1945", "Britain Since 1945", "section_03_06", None, None, 0.88),
        ]
        for slug, name, section_id, start_id, end_id, weight in history_periods:
            add(f"history.{slug}", name, "history", f"Events, people and developments in {name} covered by the handbook.", [(section_id, start_id, end_id)], weight)
        add("history.norman-britain.norman-conquest", "Norman Conquest", "history.norman-britain", "The Norman invasion and the changes that followed it.", [("section_03_01", "section_03_01_block_014", None)], 0.94)
        add("history.norman-britain.battle-of-hastings", "Battle of Hastings", "history.norman-britain", "The 1066 battle in which William's invasion defeated Harold.", [("section_03_01", "section_03_01_block_015", "section_03_01_block_016")], 0.92)
        add("history.middle-ages.magna-carta", "Magna Carta", "history.middle-ages", "The charter whose principles limited royal power and protected legal rights.", [("section_03_02", "section_03_02_block_011", "section_03_02_block_017"), ("section_05_01", "section_05_01_block_001", None)], 0.92)
        add("history.stuarts.gunpowder-plot", "Gunpowder Plot", "history.stuarts", "The unsuccessful 1605 plot to kill the Protestant king with a bomb in Parliament.", [("section_03_03", "section_03_03_block_032", "section_03_03_block_034")], 0.78)
        add("history.stuarts.english-civil-war", "English Civil War", "history.stuarts", "The conflict between the king and Parliament described in the handbook.", [("section_03_03", "section_03_03_block_039", "section_03_03_block_046")], 0.9)
        add("history.stuarts.english-republic", "English Republic", "history.stuarts", "The period when England was governed without a monarch after the Civil War.", [("section_03_03", "section_03_03_block_046", "section_03_03_block_051")], 0.76)
        add("history.stuarts.glorious-revolution", "Glorious Revolution", "history.stuarts", "The change of monarchy and constitutional settlement beginning in 1688.", [("section_03_03", "section_03_03_block_060", None)], 0.88)
        add("history.britain-since-1945.devolution", "Devolution Since 1997", "history.britain-since-1945", "The creation of devolved legislatures described in the handbook's post-war history.", [("section_03_06", "section_03_06_block_056", "section_03_06_block_058")], 0.78)

        # Cross-cutting science concepts use the historical source blocks without duplicating person concepts.
        add("science-and-invention.early-modern-science", "Early Modern Science", "science-and-invention", "Scientific work from the early modern period described in the handbook.", [("section_03_03", "section_03_03_block_056", "section_03_03_block_058")], 0.68)
        add("science-and-invention.industrial-engineering", "Industrial Engineering and Invention", "science-and-invention", "Industrial machinery, engineering and transport innovations described in the handbook.", [("section_03_04", "section_03_04_block_018", "section_03_04_block_030"), ("section_03_04", "section_03_04_block_050", "section_03_04_block_057")], 0.78)
        add("science-and-invention.medical-advances", "Medical Advances", "science-and-invention", "British medical and nursing advances described in the handbook.", [("section_03_04", "section_03_04_block_057", "section_03_04_block_061"), ("section_03_05", "section_03_05_block_028", None)], 0.76)
        add("science-and-invention.twentieth-century-inventions", "Twentieth-century British Inventions", "science-and-invention", "The inventions and scientific advances listed in the handbook's post-war chapter.", [("section_03_06", "section_03_06_block_022", "section_03_06_block_039")], 0.84)

        # Concepts needed where section prose, rather than a heading, carries the learning unit.
        add("uk-society.religious-and-ethnic-diversity", "Religious and Ethnic Diversity", "uk-society", "The diversity of the modern UK population described in the handbook.", [("section_04_01", "section_04_01_block_001", "section_04_01_block_002")], 0.74)
        add("religion.religious-diversity", "Religious Diversity", "religion", "The range and distribution of religious affiliations described in the handbook.", [("section_04_02", None, "section_04_02_block_002")], 0.72)
        add("sport.major-sporting-events", "Major Sporting Events", "sport", "Major international sporting events hosted by or involving the UK.", [("section_04_04", None, "section_04_04_block_005")], 0.62)
        add("democracy-and-constitution.development-of-democracy", "Development of British Democracy", "democracy-and-constitution", "The historical development of democratic rights and institutions in Britain.", [("section_05_01", None, None)], 0.94)
        add("law-and-justice.rule-of-law", "Rule of Law", "law-and-justice", "The principle that the law applies to everyone and that rights are protected through law.", [("section_01_01", "section_01_01_block_001", "section_01_01_block_004"), ("section_05_05", "section_05_05_block_003", "section_05_05_block_022")], 0.94)
        add("government.parliament", "UK Parliament", "government", "The elected House of Commons and appointed House of Lords acting within the UK system of government.", [("section_05_02", "section_05_02_block_027", "section_05_02_block_046")], 0.96)
        add("government.parliament.house-of-commons", "House of Commons", "government.parliament", "The elected chamber of Parliament and the work of its MPs.", [("section_05_02", "section_05_02_block_029", "section_05_02_block_035")], 0.92)
        add("government.parliament.house-of-lords", "House of Lords", "government.parliament", "The second chamber of Parliament and the work of its members.", [("section_05_02", "section_05_02_block_035", "section_05_02_block_044")], 0.84)
        add("government.elections", "Elections", "government", "How representatives are elected and how eligible voters take part.", [("section_05_02", "section_05_02_block_046", None), ("section_05_03", "section_05_03_block_068", "section_05_03_block_087")], 0.94)
        add("government.devolved-administrations", "Devolved Administrations", "government", "The legislatures and governments exercising devolved powers in Scotland, Wales and Northern Ireland.", [("section_05_03", "section_05_03_block_026", "section_05_03_block_055")], 0.9)
        add("customs-and-traditions.bonfire-night", "Bonfire Night", "customs-and-traditions", "The 5 November tradition associated with the failed Gunpowder Plot.", [("section_04_03", "section_04_03_block_014", "section_04_03_block_023")], 0.66)
        add("customs-and-traditions.remembrance-day", "Remembrance Day", "customs-and-traditions", "The November commemoration of those who died in war.", [("section_04_03", "section_04_03_block_014", "section_04_03_block_023")], 0.72)

    def heading_parent(self, section_id: str, block_id: str) -> str:
        defaults = {
            "section_01_03": "uk-values-and-citizenship.life-in-the-uk-test",
            "section_04_01": "uk-society", "section_04_02": "religion", "section_04_03": "customs-and-traditions",
            "section_04_04": "sport", "section_04_05": "arts-and-culture", "section_04_06": "leisure-and-everyday-culture",
            "section_04_07": "places-and-landmarks", "section_05_02": "democracy-and-constitution",
            "section_05_03": "government", "section_05_04": "international-relations", "section_05_05": "law-and-justice",
            "section_05_06": "law-and-justice", "section_05_07": "community-and-civic-participation"
        }
        if section_id == "section_03_01":
            return {
                "section_03_01_block_004": "history.roman-britain", "section_03_01_block_008": "history.anglo-saxon-britain",
                "section_03_01_block_011": "history.viking-britain", "section_03_01_block_014": "history.norman-britain"
            }[block_id]
        if section_id == "section_03_02": return "history.middle-ages"
        if section_id == "section_03_03": return "history.tudors" if block_id < "section_03_03_block_032" else "history.stuarts"
        if section_id == "section_03_04":
            number = int(block_id.rsplit("_", 1)[1])
            if number < 16: return "history.formation-of-great-britain"
            if number < 18: return "history.enlightenment"
            if number < 30: return "history.industrial-revolution"
            if number < 45: return "history.british-empire"
            if number < 64: return "history.victorian-britain"
            if number < 71: return "history.development-of-voting-rights"
            return "history.british-empire"
        if section_id == "section_03_05":
            number = int(block_id.rsplit("_", 1)[1])
            if number < 6: return "history.first-world-war"
            if number < 11: return "history.interwar-period"
            return "history.second-world-war"
        if section_id == "section_03_06": return "history.britain-since-1945"
        return defaults[section_id]

    def heading_concepts_and_people(self) -> None:
        canonical_targets = {
            "section_03_01_block_014": "history.norman-britain.norman-conquest",
            "section_03_03_block_042": "history.stuarts.english-civil-war",
            "section_03_03_block_046": "history.stuarts.english-republic",
            "section_03_03_block_060": "history.stuarts.glorious-revolution",
            "section_03_04_block_016": "history.enlightenment", "section_03_04_block_018": "history.industrial-revolution",
            "section_03_04_block_038": "uk-identity-and-geography.union-flag", "section_03_04_block_045": "history.victorian-britain",
            "section_03_04_block_047": "history.british-empire", "section_03_04_block_064": "history.development-of-voting-rights",
            "section_03_05_block_001": "history.first-world-war", "section_03_05_block_009": "history.interwar-period",
            "section_03_05_block_011": "history.second-world-war", "section_03_06_block_022": "science-and-invention.twentieth-century-inventions",
            "section_05_02_block_019": "uk-identity-and-geography.national-anthem",
            "section_05_02_block_029": "government.parliament.house-of-commons", "section_05_02_block_035": "government.parliament.house-of-lords",
            "section_05_02_block_046": "government.elections", "section_05_03_block_026": "government.devolved-administrations",
            "section_05_03_block_030": "government.devolved-administrations.welsh-government",
            "section_05_03_block_038": "government.devolved-administrations.scottish-parliament",
            "section_05_03_block_045": "government.devolved-administrations.northern-ireland-assembly",
            "section_05_03_block_071": "government.elections.electoral-register",
            "section_05_03_block_092": "government.devolved-administrations.northern-ireland-assembly",
            "section_05_03_block_094": "government.devolved-administrations.scottish-parliament",
            "section_05_03_block_097": "government.devolved-administrations.welsh-government",
            "section_05_06_block_027": "taxation-and-responsibilities.taxation",
            "section_05_06_block_028": "taxation-and-responsibilities.taxation.income-tax",
            "section_05_06_block_038": "taxation-and-responsibilities.national-insurance",
            "section_05_06_block_049": "taxation-and-responsibilities.driving",
            "section_05_04_block_015": "international-relations.north-atlantic-treaty-organization",
        }
        parent_overrides = {
            "section_05_02_block_002": "democracy-and-constitution",
            "section_05_02_block_013": "democracy-and-constitution.constitutional-institutions",
            "section_05_02_block_023": "democracy-and-constitution.constitutional-institutions.monarchy",
            "section_05_02_block_025": "democracy-and-constitution.constitutional-institutions.monarchy",
            "section_05_02_block_027": "democracy-and-constitution.constitutional-institutions",
            "section_05_02_block_029": "government.parliament",
            "section_05_02_block_035": "government.parliament",
            "section_05_02_block_044": "government.parliament.house-of-commons",
            "section_05_02_block_046": "government",
            "section_05_02_block_053": "government.elections",
            "section_05_03_block_026": "government",
            "section_05_03_block_030": "government.devolved-administrations",
            "section_05_03_block_038": "government.devolved-administrations",
            "section_05_03_block_045": "government.devolved-administrations",
            "section_05_03_block_068": "government.elections", "section_05_03_block_071": "government.elections", "section_05_03_block_077": "government.elections",
            "section_05_03_block_081": "government.elections", "section_05_03_block_087": "government",
            "section_05_03_block_092": "government.devolved-administrations",
            "section_05_03_block_094": "government.devolved-administrations",
            "section_05_03_block_097": "government.devolved-administrations",
            "section_05_05_block_040": "law-and-justice", "section_05_05_block_041": "law-and-justice.role-of-the-courts",
            "section_05_05_block_045": "law-and-justice.role-of-the-courts", "section_05_05_block_057": "law-and-justice.role-of-the-courts",
            "section_05_06_block_011": "law-and-justice", "section_05_06_block_017": "law-and-justice",
            "section_05_06_block_020": "law-and-justice", "section_05_06_block_022": "law-and-justice",
            "section_05_06_block_027": "taxation-and-responsibilities",
            "section_05_06_block_028": "taxation-and-responsibilities.taxation",
            "section_05_06_block_038": "taxation-and-responsibilities",
            "section_05_06_block_043": "taxation-and-responsibilities.national-insurance",
            "section_05_06_block_049": "taxation-and-responsibilities",
            "section_05_07_block_019": "community-and-civic-participation",
            "section_05_07_block_021": "community-and-civic-participation.how-you-can-support-your-community",
            "section_05_07_block_023": "community-and-civic-participation.how-you-can-support-your-community",
            "section_05_07_block_033": "community-and-civic-participation.how-you-can-support-your-community",
            "section_05_07_block_038": "community-and-civic-participation.how-you-can-support-your-community",
            "section_05_07_block_041": "community-and-civic-participation.how-you-can-support-your-community",
            "section_05_07_block_049": "community-and-civic-participation.how-you-can-support-your-community",
            "section_05_07_block_063": "community-and-civic-participation",
        }
        display_overrides = {
            "section_03_04_block_008": "Development of the Prime Minister"
        }
        last_level_three = {}
        for section_id, section in self.sections.items():
            content = section["content"]
            for index, block in enumerate(content):
                if block.get("type") != "heading": continue
                level = block.get("level", 3)
                next_index = next((candidate for candidate in range(index + 1, len(content)) if content[candidate].get("type") == "heading" and content[candidate].get("level", 3) <= level), len(content))
                end_id = content[next_index]["id"] if next_index < len(content) else None
                reference = self.range_reference(section_id, block["id"], end_id)
                title = block.get("text", "").strip()
                person_match = PERSON_HEADING.match(title)
                if person_match:
                    name = person_match.group(1).strip()
                    related = [self.heading_parent(section_id, block["id"])] + PERSON_RELATED_CONCEPTS.get(name, [])
                    entity_id = self.person_ids_by_heading.get(block["id"])
                    if not entity_id:
                        raise ValueError(f"Person heading {block['id']} has no frozen entity ID")
                    self.add_entity(entity_id, "person", name, PERSON_ALIASES.get(name, []), [reference], related)
                    continue
                if block["id"] in SKIPPED_HEADING_IDS:
                    continue
                display_name = display_overrides.get(block["id"], clean_display_name(title))
                parent_id = parent_overrides.get(block["id"], self.heading_parent(section_id, block["id"]))
                if level >= 4 and block["id"] not in parent_overrides and section_id in last_level_three:
                    parent_id = last_level_three[section_id]
                concept_id = self.concept_ids_by_heading.get(block["id"])
                if not concept_id:
                    raise ValueError(f"Concept heading {block['id']} has no frozen concept ID")
                if block["id"] in canonical_targets and canonical_targets[block["id"]] != concept_id:
                    raise ValueError(f"Canonical heading mapping changed for {block['id']}")
                resolved_id = self.add_or_merge_heading(concept_id, display_name, parent_id, reference, level)
                if level <= 3:
                    last_level_three[section_id] = resolved_id

    def entities_from_concepts_and_blocks(self) -> None:
        from_concept = {
            "history.norman-britain.norman-conquest": ("event", "Norman Conquest"),
            "history.norman-britain.battle-of-hastings": ("event", "Battle of Hastings"),
            "history.middle-ages.magna-carta": ("law", "Magna Carta"),
            "history.middle-ages.black-death": ("event", "Black Death"),
            "history.middle-ages.wars-of-the-roses": ("event", "Wars of the Roses"),
            "history.stuarts.gunpowder-plot": ("event", "Gunpowder Plot"),
            "history.stuarts.english-civil-war": ("event", "English Civil War"),
            "history.stuarts.glorious-revolution": ("event", "Glorious Revolution"),
            "history.industrial-revolution": ("event", "Industrial Revolution"),
            "history.first-world-war": ("event", "First World War"),
            "history.second-world-war": ("event", "Second World War"),
            "government.parliament": ("institution", "UK Parliament"),
            "government.parliament.house-of-commons": ("institution", "House of Commons"),
            "government.parliament.house-of-lords": ("institution", "House of Lords"),
            "government.devolved-administrations.scottish-parliament": ("institution", "Scottish Parliament"),
            "government.devolved-administrations.welsh-government": ("institution", "Welsh Government"),
            "government.devolved-administrations.northern-ireland-assembly": ("institution", "Northern Ireland Assembly"),
            "international-relations.commonwealth": ("organisation", "Commonwealth"),
            "international-relations.european-union": ("organisation", "European Union"),
            "international-relations.council-of-europe": ("organisation", "Council of Europe"),
            "international-relations.united-nations": ("organisation", "United Nations"),
            "international-relations.north-atlantic-treaty-organization": ("organisation", "North Atlantic Treaty Organization"),
        }
        for concept_id, (entity_type, display_name) in from_concept.items():
            if concept_id not in self.concepts: continue
            aliases = ALIASES.get(concept_id, [])
            self.add_entity(f"{entity_type}.{slugify(display_name)}", entity_type, display_name, aliases, self.concepts[concept_id]["handbookReferences"], [concept_id])

        for concept_id, concept in self.concepts.items():
            if concept_id.startswith("places-and-landmarks.") and concept_id.count(".") >= 2:
                self.add_entity(f"place.{concept_id.rsplit('.', 1)[-1]}", "place", concept["displayName"], [], concept["handbookReferences"], [concept_id])

        curated = [
            ("person.william-the-conqueror", "person", "William the Conqueror", ["William, the Duke of Normandy"], ["William the Conqueror"], ["history.norman-britain.norman-conquest"]),
            ("person.henry-viii", "person", "Henry VIII", ["King Henry VIII"], ["Henry VIII"], ["history.tudors"]),
            ("person.elizabeth-i", "person", "Elizabeth I", ["Queen Elizabeth I"], ["Queen Elizabeth I", "Elizabeth I"], ["history.tudors"]),
            ("person.oliver-cromwell", "person", "Oliver Cromwell", [], ["Oliver Cromwell"], ["history.stuarts.english-republic"]),
            ("person.guy-fawkes", "person", "Guy Fawkes", [], ["Guy Fawkes"], ["history.stuarts.gunpowder-plot", "customs-and-traditions.bonfire-night"]),
            ("document.domesday-book", "document", "Domesday Book", [], ["Domesday Book"], ["history.norman-britain.norman-conquest"]),
            ("document.king-james-bible", "document", "King James Bible", ["Authorised Version"], ["King James Bible", "Authorised Version"], ["history.stuarts.king-james-bible"]),
            ("document.bill-of-rights", "document", "Bill of Rights", [], ["Bill of Rights"], ["history.stuarts.glorious-revolution", "democracy-and-constitution.development-of-democracy"]),
            ("work.bayeux-tapestry", "work", "Bayeux Tapestry", [], ["Bayeux Tapestry"], ["history.norman-britain.battle-of-hastings"]),
            ("place.stonehenge", "place", "Stonehenge", [], ["Stonehenge"], ["history.prehistoric-britain"]),
            ("place.skara-brae", "place", "Skara Brae", [], ["Skara Brae"], ["history.prehistoric-britain"]),
            ("place.hadrians-wall", "place", "Hadrian's Wall", [], ["Hadrian's Wall"], ["history.roman-britain"]),
            ("institution.national-health-service", "institution", "National Health Service", ["NHS"], ["National Health Service", "NHS"], ["history.britain-since-1945.welfare-state"]),
        ]
        invention_blocks = {
            "television": ("Television", "section_03_06_block_024"), "radar": ("Radar", "section_03_06_block_025"),
            "radio-telescope": ("Radio Telescope", "section_03_06_block_026"), "turing-machine": ("Turing Machine", "section_03_06_block_027"),
            "insulin": ("Insulin", "section_03_06_block_028"), "dna-structure": ("DNA Structure", "section_03_06_block_029"),
            "jet-engine": ("Jet Engine", "section_03_06_block_030"), "hovercraft": ("Hovercraft", "section_03_06_block_031"),
            "concorde": ("Concorde", "section_03_06_block_032"), "harrier-jump-jet": ("Harrier Jump Jet", "section_03_06_block_033"),
            "cash-dispensing-atm": ("Cash-dispensing ATM", "section_03_06_block_034"), "ivf": ("IVF", "section_03_06_block_035"),
            "mammal-cloning": ("Mammal Cloning", "section_03_06_block_036"), "mri-scanner": ("MRI Scanner", "section_03_06_block_037"),
            "world-wide-web": ("World Wide Web", "section_03_06_block_038")
        }
        for slug, (display_name, block_id) in invention_blocks.items():
            reference = self.range_reference("section_03_06", block_id, self.next_block_id("section_03_06", block_id))
            self.add_entity(f"invention.{slug}", "invention", display_name, [], [reference], ["science-and-invention.twentieth-century-inventions"])

        all_block_text = {block_id: plain_text(block).casefold() for block_id, block in self.blocks.items()}
        for entity_id, entity_type, display_name, aliases, terms, preferred in curated:
            matched = [block_id for block_id, text in all_block_text.items() if any(term.casefold() in text for term in terms)]
            references = self.references_for_block_ids(matched)
            if references:
                self.add_entity(entity_id, entity_type, display_name, aliases, references, preferred)

        key_dates = ["1066", "1215", "1348", "1485", "1534", "1588", "1605", "1642", "1649", "1660", "1688", "1707", "1801", "1837", "1914", "1918", "1928", "1939", "1945", "1948", "1973", "1979", "1998", "2010"]
        for year in key_dates:
            pattern = re.compile(rf"(?<!\d){re.escape(year)}(?!\d)")
            matched = [block_id for block_id, text in all_block_text.items() if pattern.search(text)]
            references = self.references_for_block_ids(matched)
            if references:
                self.add_entity(f"date.{year}", "date", year, [], references)

    def next_block_id(self, section_id: str, block_id: str) -> str | None:
        ids = [block["id"] for block in self.sections[section_id]["content"]]
        index = ids.index(block_id)
        return ids[index + 1] if index + 1 < len(ids) else None

    def references_for_block_ids(self, block_ids: list[str]) -> list[dict]:
        grouped = defaultdict(list)
        for block_id in block_ids:
            grouped[self.block_sections[block_id]].append(block_id)
        return [{"chapterId": self.section_chapters[section_id], "sectionId": section_id, "blockIds": ids} for section_id, ids in grouped.items()]

    def add_relationships(self) -> None:
        pairs = [
            ("history.middle-ages.magna-carta", "law-and-justice.rule-of-law"),
            ("history.middle-ages.magna-carta", "democracy-and-constitution.development-of-democracy"),
            ("history.norman-britain.norman-conquest", "history.norman-britain.battle-of-hastings"),
            ("history.stuarts.gunpowder-plot", "customs-and-traditions.bonfire-night"),
            ("history.first-world-war", "customs-and-traditions.remembrance-day"),
            ("history.second-world-war", "customs-and-traditions.remembrance-day"),
            ("history.britain-since-1945.devolution", "government.devolved-administrations"),
            ("uk-values-and-citizenship.fundamental-british-values.democracy", "democracy-and-constitution.development-of-democracy"),
            ("uk-values-and-citizenship.fundamental-british-values", "law-and-justice.rule-of-law"),
            ("uk-values-and-citizenship.fundamental-british-values.community-participation", "community-and-civic-participation.values-and-responsibilities"),
            ("uk-identity-and-geography.countries", "government.devolved-administrations"),
            ("history.formation-of-great-britain", "uk-identity-and-geography.union-flag"),
            ("history.industrial-revolution", "science-and-invention.industrial-engineering"),
            ("history.britain-since-1945", "science-and-invention.twentieth-century-inventions"),
            ("history.britain-since-1945.europe-and-common-market", "international-relations.european-union"),
            ("democracy-and-constitution.constitutional-institutions.system-of-government", "government.parliament"),
            ("government.elections", "community-and-civic-participation.supporting-political-parties"),
            ("government.devolved-administrations", "uk-identity-and-geography.united-kingdom"),
            ("law-and-justice.rule-of-law", "democracy-and-constitution.constitutional-institutions"),
        ]
        for left, right in pairs:
            if left in self.concepts and right in self.concepts: self.relate(left, right)
        for left, right in self.relationship_pairs:
            self.concepts[left]["relatedConceptIds"].append(right)
            self.concepts[right]["relatedConceptIds"].append(left)

    def finalize_hierarchy_and_entities(self) -> None:
        for concept in self.concepts.values():
            parent_id = concept["parentId"]
            if parent_id:
                self.concepts[parent_id]["childIds"].append(concept["id"])

        concept_blocks = {concept_id: {block_id for reference in concept["handbookReferences"] for block_id in reference["blockIds"]} for concept_id, concept in self.concepts.items()}
        depths = {concept_id: concept_id.count(".") for concept_id in self.concepts}
        for entity in self.entities.values():
            entity_blocks = {block_id for reference in entity["handbookReferences"] for block_id in reference["blockIds"]}
            preferred = {concept_id for concept_id in entity.pop("_preferredConceptIds") if concept_id in self.concepts}
            related_ids = set(preferred)
            if not preferred:
                for block_id in entity_blocks:
                    candidates = [concept_id for concept_id, block_ids in concept_blocks.items() if block_id in block_ids]
                    if candidates:
                        max_depth = max(depths[concept_id] for concept_id in candidates)
                        related_ids.update(concept_id for concept_id in candidates if depths[concept_id] == max_depth)
            if related_ids:
                related = [concept_id for concept_id in self.concept_order if concept_id in related_ids]
                entity["relatedConceptIds"] = related
                for concept_id in related:
                    self.concepts[concept_id]["entityIds"].append(entity["id"])

        for concept in self.concepts.values():
            concept["relatedConceptIds"] = sorted(set(concept["relatedConceptIds"]))
            concept["entityIds"] = sorted(set(concept["entityIds"]))

    def ordered_concepts(self) -> list[dict]:
        order_index = {concept_id: index for index, concept_id in enumerate(self.concept_order)}
        roots = [concept_id for concept_id, *_ in DOMAIN_SPECS]
        result = []
        def visit(concept_id: str):
            result.append(self.concepts[concept_id])
            for child_id in sorted(self.concepts[concept_id]["childIds"], key=lambda value: order_index[value]):
                visit(child_id)
        for root in roots: visit(root)
        return result

    def ordered_entities(self) -> list[dict]:
        type_index = {value: index for index, value in enumerate(ENTITY_TYPE_ORDER)}
        return sorted(self.entities.values(), key=lambda entity: (type_index[entity["type"]], entity["displayName"].casefold(), entity["id"]))

    def document(self) -> dict:
        return {
            "schemaVersion": 1,
            "taxonomyVersion": "1.0.0",
            "handbookVersion": f"{self.handbook['content_version']}.0.0",
            "generatedAt": GENERATED_AT,
            "concepts": self.ordered_concepts(),
            "entities": self.ordered_entities(),
        }

    def validate(self, document: dict) -> list[str]:
        errors = []
        concepts = document["concepts"]
        entities = document["entities"]
        concept_ids = [concept["id"] for concept in concepts]
        entity_ids = [entity["id"] for entity in entities]
        concept_map = {concept["id"]: concept for concept in concepts}
        entity_set = set(entity_ids)
        if len(concept_ids) != len(set(concept_ids)): errors.append("Concept IDs are not unique.")
        if len(entity_ids) != len(set(entity_ids)): errors.append("Entity IDs are not unique.")
        for concept in concepts:
            if not ID_PATTERN.fullmatch(concept["id"]): errors.append(f"Invalid concept ID: {concept['id']}")
            if concept["domainId"] not in {domain_id for domain_id, *_ in DOMAIN_SPECS}: errors.append(f"Invalid domain ID on {concept['id']}")
            parent_id = concept["parentId"]
            if parent_id is None and concept["id"] not in {domain_id for domain_id, *_ in DOMAIN_SPECS}: errors.append(f"Non-root concept has no parent: {concept['id']}")
            if parent_id is not None:
                if parent_id not in concept_map: errors.append(f"Missing parent {parent_id} for {concept['id']}")
                elif concept["id"] not in concept_map[parent_id]["childIds"]: errors.append(f"Parent-child mismatch for {concept['id']}")
            if len(concept["childIds"]) != len(set(concept["childIds"])): errors.append(f"Duplicate children on {concept['id']}")
            for child_id in concept["childIds"]:
                if child_id not in concept_map: errors.append(f"Missing child {child_id}")
                elif concept_map[child_id]["parentId"] != concept["id"]: errors.append(f"Child-parent mismatch for {child_id}")
            for related_id in concept["relatedConceptIds"]:
                if related_id not in concept_map: errors.append(f"Missing related concept {related_id}")
                elif concept["id"] not in concept_map[related_id]["relatedConceptIds"]: errors.append(f"Asymmetric related concepts: {concept['id']} and {related_id}")
            for entity_id in concept["entityIds"]:
                if entity_id not in entity_set: errors.append(f"Missing entity {entity_id}")
            if not 0 <= concept["importance"]["weight"] <= 1: errors.append(f"Invalid importance weight on {concept['id']}")
            if concept["displayName"].casefold() in {alias.casefold() for alias in concept["aliases"]}: errors.append(f"Redundant canonical alias on {concept['id']}")
            errors.extend(self.reference_errors(concept["id"], concept["handbookReferences"]))
        for entity in entities:
            if not ID_PATTERN.fullmatch(entity["id"]): errors.append(f"Invalid entity ID: {entity['id']}")
            if entity["type"] not in ENTITY_TYPE_ORDER: errors.append(f"Invalid entity type on {entity['id']}")
            for concept_id in entity["relatedConceptIds"]:
                if concept_id not in concept_map: errors.append(f"Missing entity related concept {concept_id}")
            errors.extend(self.reference_errors(entity["id"], entity["handbookReferences"]))
        for concept_id in concept_ids:
            seen = set()
            current = concept_id
            while current is not None:
                if current in seen:
                    errors.append(f"Hierarchy cycle at {concept_id}")
                    break
                seen.add(current)
                current = concept_map[current]["parentId"]
        return errors

    def reference_errors(self, owner_id: str, references: list[dict]) -> list[str]:
        errors = []
        for reference in references:
            chapter_id, section_id = reference["chapterId"], reference["sectionId"]
            if chapter_id not in self.chapters: errors.append(f"Missing chapter {chapter_id} on {owner_id}")
            if section_id not in self.sections: errors.append(f"Missing section {section_id} on {owner_id}")
            elif self.section_chapters[section_id] != chapter_id: errors.append(f"Chapter-section mismatch on {owner_id}")
            for block_id in reference["blockIds"]:
                if block_id not in self.blocks: errors.append(f"Missing block {block_id} on {owner_id}")
                elif self.block_sections[block_id] != section_id: errors.append(f"Section-block mismatch on {owner_id}")
        return errors

    def diagnostics(self, document: dict) -> dict:
        concepts, entities = document["concepts"], document["entities"]
        relationship_count = sum(len(concept["relatedConceptIds"]) for concept in concepts) // 2
        sections = {reference["sectionId"] for concept in concepts for reference in concept["handbookReferences"]}
        blocks = {block_id for concept in concepts for reference in concept["handbookReferences"] for block_id in reference["blockIds"]}
        no_references = [concept["id"] for concept in concepts if not concept["handbookReferences"]]
        suspicious = [concept["id"] for concept in concepts if not concept["childIds"] and concept["id"] in {domain_id for domain_id, *_ in DOMAIN_SPECS}]
        uncovered_sections = sorted(set(self.sections) - sections)
        aliases = defaultdict(list)
        for concept in concepts:
            for alias in concept["aliases"]: aliases[alias.casefold()].append(concept["id"])
        duplicate_aliases = {alias: ids for alias, ids in aliases.items() if len(ids) > 1}
        names = defaultdict(list)
        for concept in concepts: names[concept["displayName"].casefold()].append(concept["id"])
        possible_duplicates = {name: ids for name, ids in names.items() if len(ids) > 1}
        return {
            "domains": len([concept for concept in concepts if concept["parentId"] is None]),
            "concepts": len(concepts), "leafConcepts": sum(not concept["childIds"] for concept in concepts),
            "entities": len(entities), "conceptRelationships": relationship_count,
            "handbookSectionsUsed": len(sections), "handbookBlocksLinked": len(blocks),
            "conceptsWithNoReferences": no_references, "suspiciousBroadLeaves": suspicious,
            "handbookSectionsWithNoCoverage": uncovered_sections, "duplicateAliases": duplicate_aliases,
            "possibleDuplicateConcepts": possible_duplicates,
            "ambiguities": [
                "No standalone source taxonomy file was supplied; the 17 named domains and required history periods in the task specification were treated as the canonical seed.",
                "Magna Carta is canonical under medieval history and related to rule of law and democratic development rather than duplicated across domains.",
                "Rule of law is canonical under law and justice and related to fundamental British values rather than duplicated as a values child.",
                "Named people and individual inventions are entities unless the handbook presents a broader testable concept; profile headings do not create duplicate person concepts.",
                "The Union Flag and National Anthem are canonical identity concepts even though their source passages occur in history and constitution sections.",
            ]
        }


def main() -> int:
    handbook = json.loads(HANDBOOK_PATH.read_text(encoding="utf-8"))
    builder = TaxonomyBuilder(handbook)
    builder.fixed_concepts()
    builder.heading_concepts_and_people()
    builder.entities_from_concepts_and_blocks()
    builder.add_relationships()
    builder.finalize_hierarchy_and_entities()
    document = builder.document()
    errors = builder.validate(document)
    if errors:
        print("Taxonomy validation failed:", file=sys.stderr)
        for error in errors: print(f"  - {error}", file=sys.stderr)
        return 1
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    diagnostics = builder.diagnostics(document)
    print("Taxonomy generation complete\n")
    labels = [
        ("Domains", diagnostics["domains"]), ("Concepts", diagnostics["concepts"]), ("Leaf concepts", diagnostics["leafConcepts"]),
        ("Entities", diagnostics["entities"]), ("Concept relationships", diagnostics["conceptRelationships"]),
        ("Handbook sections used", diagnostics["handbookSectionsUsed"]), ("Handbook blocks linked", diagnostics["handbookBlocksLinked"]),
    ]
    for label, value in labels: print(f"{label + ':':28} {value}")
    print("\nValidation:\n✓ IDs unique\n✓ Hierarchy valid\n✓ No cycles\n✓ Related concepts valid\n✓ Entity references valid\n✓ Handbook references valid\n✓ Importance weights valid")
    print("\nWarnings:")
    for key in ["conceptsWithNoReferences", "suspiciousBroadLeaves", "handbookSectionsWithNoCoverage", "duplicateAliases", "possibleDuplicateConcepts"]:
        print(f"- {key}: {json.dumps(diagnostics[key], ensure_ascii=False)}")
    print("- unresolvedOrAmbiguousReferences:")
    for ambiguity in diagnostics["ambiguities"]: print(f"  - {ambiguity}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
