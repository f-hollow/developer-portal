#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.request
import urllib.error


def read_prompt_from_file(file_path: str) -> str:
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except Exception as exc:
        print(f"Failed to read prompt file '{file_path}': {exc}", file=sys.stderr)
        sys.exit(1)


def build_request(prompt: str, model: str) -> dict:
    return {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Send a chat completion request to an LLM/OpenAI-compatible API."
    )
    parser.add_argument(
        "--llm-model", required=True, help="Model name to use for the request."
    )
    parser.add_argument(
        "--prompt", required=True, help="Path to the file containing the prompt text."
    )
    parser.add_argument(
        "--response", required=True, help="Path to save the JSON response."
    )
    parser.add_argument(
        "--output-json",
        default=None,
        help="Path to consolidated evaluation JSON to merge LLM fields into.",
    )
    parser.add_argument(
        "--article-path",
        default=None,
        help="Article path (key in output-json). Required when --output-json is set.",
    )
    parser.add_argument(
        "--prompt-tmpl-ver",
        default="unknown",
        help="Prompt template version to store (e.g. v0.1). Used when --output-json is set.",
    )
    args = parser.parse_args()

    if args.output_json is not None and args.article_path is None:
        print("When --output-json is set, --article-path is required.", file=sys.stderr)
        return 1

    prompt = read_prompt_from_file(args.prompt)

    api_key = os.getenv("LLM_API_KEY")
    base_url = os.getenv("LLM_BASE_URL")
    model = args.llm_model

    if not api_key or not base_url:
        print(
            "Missing LLM_API_KEY or LLM_BASE_URL in environment.",
            file=sys.stderr,
        )
        return 1

    payload = build_request(prompt, model)
    data = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(
        base_url,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            # Cap read size so we never block forever on a streaming/keepalive connection
            body = resp.read(5 * 1024 * 1024)
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        print(f"HTTP {exc.code}: {err_body}", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"Request failed: {exc}", file=sys.stderr)
        return 1

    try:
        response_json = json.loads(body)
    except json.JSONDecodeError as exc:
        print(f"Failed to parse JSON: {exc}", file=sys.stderr)
        print(body.decode("utf-8", errors="replace"), file=sys.stderr)
        return 1

    # Save JSON response to file
    response_dir = os.path.dirname(args.response)
    if response_dir:
        os.makedirs(response_dir, exist_ok=True)
    with open(args.response, "w", encoding="utf-8") as f:
        json.dump(response_json, f, ensure_ascii=False, indent=2)

    # Merge LLM fields into consolidated output JSON when requested
    if args.output_json is not None:
        if os.path.isfile(args.output_json):
            with open(args.output_json, "r", encoding="utf-8") as f:
                output_data = json.load(f)
        else:
            output_data = {}
        entry = output_data.setdefault(args.article_path, {"manual_tags": None})
        entry["prompt_tmpl_ver"] = args.prompt_tmpl_ver
        entry["created"] = response_json.get("created")
        entry["model"] = response_json.get("model")
        entry["choices"] = response_json.get("choices")
        entry["usage"] = response_json.get("usage")
        output_dir = os.path.dirname(args.output_json)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
        with open(args.output_json, "w", encoding="utf-8") as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
