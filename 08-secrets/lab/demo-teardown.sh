#!/usr/bin/env bash
# Delete the lab cluster. Run this after the session.
set -euo pipefail
kind delete cluster --name secrets-lab
