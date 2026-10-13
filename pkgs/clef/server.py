"""Text/JSON SystemOne API for the locally downloaded Clef-flash release."""

import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()

    import torch
    from transformers import BitsAndBytesConfig

    sys.path.insert(0, str(args.model_dir))
    from joint_schema_model import load_release_model, systemone

    # Quantize only the backbone; the release loader keeps the joint head in BF16.
    model, processor = load_release_model(
        args.model_dir,
        device="cuda",
        local_files_only=True,
        quantization_config=BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_use_double_quant=True,
            bnb_4bit_compute_dtype=torch.bfloat16,
        ),
    )

    class Handler(BaseHTTPRequestHandler):
        def send_json(self, status, payload):
            data = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path == "/health":
                self.send_json(200, {"status": "ok"})
            elif self.path == "/v1/models":
                self.send_json(200, {"object": "list", "data": [
                    {"id": "clef-flash", "object": "model"}
                ]})
            else:
                self.send_json(404, {"error": "not found"})

        def do_POST(self):
            if self.path != "/v1/systemone":
                self.send_json(404, {"error": "not found"})
                return
            try:
                body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
                if not isinstance(body, dict):
                    raise ValueError("request must be an object")
                if body.get("images") or body.get("videos"):
                    raise ValueError("this endpoint accepts text/JSON state, not images or videos")
                body.setdefault("model", "clef-flash")
                result = systemone(model, processor, body)
            except (ValueError, KeyError, TypeError, AttributeError) as exc:
                self.send_json(400, {"error": str(exc)})
                return
            self.send_json(200, result)

    # Serialize inference to avoid concurrent requests exhausting GPU memory.
    server = HTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Clef-flash ready on 127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
