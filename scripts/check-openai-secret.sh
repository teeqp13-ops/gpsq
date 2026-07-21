#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo 'OPENAI_API_KEY is not configured.' >&2
  exit 1
fi

if [[ "${#OPENAI_API_KEY}" -lt 20 ]]; then
  echo 'OPENAI_API_KEY appears invalid.' >&2
  exit 1
fi

echo 'OPENAI_API_KEY is configured.'
