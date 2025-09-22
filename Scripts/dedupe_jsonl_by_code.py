import argparse
import json


def main() -> None:
    parser = argparse.ArgumentParser(description="Dedupe JSONL entries by 'code' field.")
    parser.add_argument("input", help="Input JSONL path")
    parser.add_argument("output", help="Output JSONL path")
    args = parser.parse_args()

    seen = set()
    kept = 0
    total = 0

    with open(args.input, "r", encoding="utf-8") as src, open(args.output, "w", encoding="utf-8") as dst:
        for line in src:
            total += 1
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue

            code = data.get("code")
            if not isinstance(code, str):
                continue
            if code in seen:
                continue
            seen.add(code)
            dst.write(json.dumps(data, ensure_ascii=False) + "\n")
            kept += 1

    print(f"Read {total:,} entries, kept {kept:,} unique codes, dropped {total - kept:,} duplicates.")


if __name__ == "__main__":
    main()
