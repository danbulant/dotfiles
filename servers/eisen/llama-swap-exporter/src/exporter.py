#!/usr/bin/env python

"""Prometheus exporter for llama-swap metrics endpoint."""

import json
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

LLAMA_SWAP_URL = os.environ.get("LLAMA_SWAP_URL", "http://localhost:8080/metrics")
PROMETHEUS_PORT = int(os.environ.get("PROMETHEUS_PORT", "9409"))
SCRAPE_INTERVAL = int(os.environ.get("SCRAPE_INTERVAL", "15"))

last_metrics = {}
last_scrape_time = 0


def scrape_llama_swap():
    try:
        req = urllib.request.Request(LLAMA_SWAP_URL)
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            if not data:
                print("No data found when scraping (request successful, empty data)")
                return {}
            entry = data[-1]
            return {
                "llama_cache_tokens": float(entry.get("cache_tokens", 0)),
                "llama_input_tokens": float(entry.get("input_tokens", 0)),
                "llama_output_tokens": float(entry.get("output_tokens", 0)),
                "llama_prompt_per_second": entry.get("prompt_per_second", 0),
                "llama_tokens_per_second": entry.get("tokens_per_second", 0),
                "llama_duration_ms": float(entry.get("duration_ms", 0)),
                "llama_model": entry.get("model", "unknown"),
                "llama_has_capture": 1 if entry.get("has_capture") else 0,
            }
    except Exception as e:
        print(f"Error scraping llama-swap: {e}")
        return {}


def format_metrics(metrics):
    if not metrics:
        metrics = {}

    lines = []
    model = metrics.get("llama_model", "unknown")

    for name, value in metrics.items():
        if name == "llama_model":
            continue
        if "second" in name:
            lines.append(f"# HELP {name} Rate from llama-swap")
            lines.append(f"# TYPE {name} gauge")
            lines.append(f'{name}{{model="{model}"}} {value}')
        elif "tokens" in name:
            lines.append(f"# HELP {name} Total tokens from llama-swap")
            lines.append(f"# TYPE {name} gauge")
            lines.append(f'{name}{{model="{model}"}} {value}')
        elif "duration" in name:
            value_s = value / 1000.0
            lines.append("# HELP llama_duration_seconds Inference duration")
            lines.append("# TYPE llama_duration_seconds gauge")
            lines.append(f'llama_duration_seconds{{model="{model}"}} {value_s}')
        elif name == "llama_has_capture":
            lines.append("# HELP llama_has_capture Whether capture is available")
            lines.append("# TYPE llama_has_capture gauge")
            lines.append(f'llama_has_capture{{model="{model}"}} {value}')

    lines.append(
        "# HELP llama_last_scrape_timestamp_seconds When metrics were last scraped"
    )
    lines.append("# TYPE llama_last_scrape_timestamp_seconds gauge")
    lines.append(f"llama_last_scrape_timestamp_seconds {time.time()}")

    return "\n".join(lines) + "\n"


last_metrics = None


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global last_scrape_time, last_metrics
        if time.time() - last_scrape_time > SCRAPE_INTERVAL:
            last_metrics = scrape_llama_swap()
            last_scrape_time = time.time()

        if self.path == "/metrics":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(format_metrics(last_metrics).encode())
        elif self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    print(f"Starting llama-swap exporter on port {PROMETHEUS_PORT}")
    print(f"Scraping llama-swap from: {LLAMA_SWAP_URL}")
    server = HTTPServer(("0.0.0.0", PROMETHEUS_PORT), MetricsHandler)
    server.serve_forever()
else:
    print("Exporter loaded")
