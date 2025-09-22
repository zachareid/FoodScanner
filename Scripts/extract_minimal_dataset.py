import argparse
import json
from typing import Optional


def choose_name(product: dict) -> Optional[str]:
    for key in (
        "product_name",
        "product_name_en",
        "generic_name",
        "generic_name_en",
    ):
        value = product.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    brands = product.get("brands")
    if isinstance(brands, str) and brands.strip():
        return brands.strip()
    return None


def choose_score(product: dict) -> Optional[float]:
    candidate = product.get("nutriscore_score")
    if isinstance(candidate, (int, float)):
        return float(candidate)

    nutriscore_data = product.get("nutriscore_data")
    if isinstance(nutriscore_data, dict):
        score = nutriscore_data.get("score")
        if isinstance(score, (int, float)):
            return float(score)

    # Fall back to the legacy field if present
    legacy = product.get("nutrition_score_fr_100g")
    if isinstance(legacy, (int, float)):
        return float(legacy)

    return None


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract minimal barcode→(score,name) mapping from Open Food Facts dump.")
    parser.add_argument("input", help="Path to openfoodfacts-products.jsonl dump")
    parser.add_argument("output", help="Path to write minimal JSONL mapping")
    args = parser.parse_args()

    total = 0
    written = 0

    with open(args.input, "r", encoding="utf-8") as source, open(args.output, "w", encoding="utf-8") as sink:
        for line in source:
            total += 1
            line = line.strip()
            if not line:
                continue

            try:
                product = json.loads(line)
            except json.JSONDecodeError:
                continue

            code = product.get("code")
            if not isinstance(code, str) or not code.strip():
                continue

            score = choose_score(product)
            name = choose_name(product)

            if score is None or name is None:
                continue

            entry = {
                "code": code.strip(),
                "score": score,
                "name": name,
            }
            sink.write(json.dumps(entry, ensure_ascii=False) + "\n")
            written += 1

            if written % 100000 == 0:
                sink.flush()

    print(f"Processed {total:,} products; wrote {written:,} minimal entries.")


if __name__ == "__main__":
    main()
