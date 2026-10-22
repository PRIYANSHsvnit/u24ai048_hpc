#!/bin/bash
#SBATCH --job-name=stage35-check
#SBATCH --partition=gpu
#SBATCH --gres=shard:1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:05:00
#SBATCH --output=stage35_check_%j.out
#SBATCH --error=stage35_check_%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

module purge
module load anaconda3-2024.2
module load cuda-12.8

echo "Job ID: ${SLURM_JOB_ID:-unknown}"
echo "Compute host: $(hostname)"
echo "Python: $(command -v python)"
python --version
nvidia-smi

python - <<'PY'
import importlib
import sys

required = ["numpy", "scipy", "matplotlib", "torch", "nbconvert", "IPython"]
for name in required:
    try:
        mod = importlib.import_module(name)
        print(f"{name}: {getattr(mod, '__version__', 'import OK')}")
    except Exception as exc:
        print(f"IMPORT FAILED: {name}: {type(exc).__name__}: {exc}")
        raise

import matplotlib
from packaging.version import Version
import torch
print(f"PyTorch CUDA build: {torch.version.cuda}")
print(f"CUDA visible to PyTorch: {torch.cuda.is_available()}")
if not torch.cuda.is_available():
    raise SystemExit("FAIL: this Slurm job has no CUDA-visible GPU; do not launch the benchmark yet.")
print(f"GPU: {torch.cuda.get_device_name(0)}")
if Version(matplotlib.__version__) < Version("3.9"):
    raise SystemExit(
        "FAIL: this notebook uses matplotlib boxplot(tick_labels=...), which requires matplotlib >= 3.9. "
        "Load a newer module/environment or change that argument to labels= in the notebook copy."
    )
print("PREFLIGHT PASSED")
PY
