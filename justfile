setup:
    uv sync
    uv run fusesoc library add .
    uv run fusesoc library add fusesoc-packages https://github.com/fusesoc/fusesoc-cores
    uv run fusesoc library add wb_intercon https://github.com/olofk/wb_intercon
    uv run fusesoc library add cdc_utils https://github.com/fusesoc/cdc_utils

sim:
    uv run fusesoc run --target sim :bloeckchengrafik:muframe:0.1

sim-vcd-surfer:
    surfer build/*/sim-icarus/muf_tb.vcd

filelist target="default":
    #!/usr/bin/env bash
    set -euo pipefail

    build_root="$(pwd)/.fusesoc-lsp/{{target}}"

    rm -rf "$build_root"

    uv run fusesoc run \
        --target="{{target}}" \
        --setup \
        --no-export \
        --build-root="$build_root" \
        :bloeckchengrafik:muframe:0.1

    edam="$(find "$build_root" -name '*.eda.yml' -print -quit)"

    if [[ -z "$edam" ]]; then
        echo "error: no .eda.yml generated" >&2
        exit 1
    fi

    uv run python tools/fusesoc_filelist.py \
        "$edam" \
        --output verible.filelist
