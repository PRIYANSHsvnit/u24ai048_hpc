#!/bin/bash
#SBATCH --job-name=stage35-confirm
#SBATCH --partition=gpu
#SBATCH --gres=shard:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=24:00:00
#SBATCH --output=stage35_%j.out
#SBATCH --error=stage35_%j.err

set -euo pipefail
cd "$SLURM_SUBMIT_DIR"

NOTEBOOK="pinn_stage35_1_standardized_confirmatory_benchmark.ipynb"
if [[ ! -f "$NOTEBOOK" ]]; then
  echo "ERROR: Cannot find $NOTEBOOK in $SLURM_SUBMIT_DIR"
  echo "Upload the notebook and submit this script from the same directory."
  exit 2
fi

module purge
module load anaconda3-2024.2
module load cuda-12.8

RUN_DIR="$SLURM_SUBMIT_DIR/runs/stage35_${SLURM_JOB_ID}"
mkdir -p "$RUN_DIR"
cp "$NOTEBOOK" "$RUN_DIR/"
# If reference data were pre-uploaded because compute-node internet is blocked, stage them here.
for asset in burgers_shock.mat allen_cahn.mat official_soap.py; do
  if [[ -f "$SLURM_SUBMIT_DIR/$asset" ]]; then
    cp "$SLURM_SUBMIT_DIR/$asset" "$RUN_DIR/"
  fi
done
cd "$RUN_DIR"

export MPLBACKEND=Agg
export PYTHONUNBUFFERED=1
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
export OPENBLAS_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"
export MKL_NUM_THREADS="${SLURM_CPUS_PER_TASK:-4}"

printf 'Job ID: %s\nCompute host: %s\nRun directory: %s\n' "$SLURM_JOB_ID" "$(hostname)" "$RUN_DIR"
nvidia-smi

# Fail early if the loaded modules lack a working GPU stack or notebook executor.
python - <<'PY'
import importlib
for name in ["numpy", "scipy", "matplotlib", "torch", "nbconvert", "IPython"]:
    mod = importlib.import_module(name)
    print(f"{name}: {getattr(mod, '__version__', 'import OK')}")
import matplotlib
from packaging.version import Version
import torch
print(f"PyTorch CUDA build: {torch.version.cuda}")
if not torch.cuda.is_available():
    raise SystemExit("ERROR: CUDA is not visible inside the allocated Slurm job; stopping to avoid CPU execution.")
print(f"GPU: {torch.cuda.get_device_name(0)}")
if Version(matplotlib.__version__) < Version("3.9"):
    raise SystemExit(
        "ERROR: notebook uses matplotlib boxplot(tick_labels=...), requiring matplotlib >= 3.9. "
        "Use a newer module/environment or change tick_labels= to labels= in the run copy."
    )
PY

python -m nbconvert \
  --to notebook \
  --execute "$NOTEBOOK" \
  --output "executed_${SLURM_JOB_ID}.ipynb" \
  --output-dir "$RUN_DIR" \
  --ExecutePreprocessor.timeout=-1

ARCHIVE="$SLURM_SUBMIT_DIR/stage35_results_${SLURM_JOB_ID}.tar.gz"
tar -czf "$ARCHIVE" -C "$RUN_DIR" master_outputs "executed_${SLURM_JOB_ID}.ipynb"
echo "SUCCESS: results archive: $ARCHIVE"
echo "Output files:"
find "$RUN_DIR/master_outputs" -maxdepth 1 -type f -printf '%f (%s bytes)\n' | sort
