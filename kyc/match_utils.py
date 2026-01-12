import re
from difflib import SequenceMatcher


def normalize_name(name: str) -> str:
    name = (name or "").lower().strip()
    name = re.sub(r"[^a-z\s]", " ", name)
    name = re.sub(r"\s+", " ", name).strip()
    return name


def name_similarity(a: str, b: str) -> float:
    a_n = normalize_name(a)
    b_n = normalize_name(b)
    if not a_n or not b_n:
        return 0.0
    return SequenceMatcher(None, a_n, b_n).ratio()
