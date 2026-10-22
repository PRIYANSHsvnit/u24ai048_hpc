SVNIT Aurora HPC: Stage 35.1 notebook workflow

Files to place together in your HPC project directory:
- pinn_stage35_1_standardized_confirmatory_benchmark.ipynb
- stage35_preflight.sh
- run_stage35_hpc.sh

Before submitting:
1. Check module names and GPU partition limits on the login node:
   module avail
   scontrol show partition gpu
   sinfo
2. The scripts use module names from the supplied submitnew.sh/manual:
   anaconda3-2024.2 and cuda-12.8. Change them only if `module avail` shows different names.
3. The scripts request --gres=shard:1 as in the HPC manual; they intentionally do not pin --nodelist.
4. The run script defaults to 24 hours, 4 CPUs, and 16 GB RAM. Adjust these SBATCH requests to the limits/requirements confirmed by HPC staff. This benchmark performs 90 new runs at 5,000 steps each, so it may need substantial time.
5. Run the preflight first:
   sbatch stage35_preflight.sh
   squeue -u "$USER"
   cat stage35_check_JOBID.out
   cat stage35_check_JOBID.err
   Replace JOBID with the numeric ID returned by sbatch. Proceed only if it says PREFLIGHT PASSED.
6. Submit the benchmark from the directory containing the notebook and script:
   sbatch run_stage35_hpc.sh
   squeue -u "$USER"
   tail -f stage35_JOBID.out
   Use Ctrl+C to stop tailing (this does not stop the job). Cancel a job with scancel JOBID.
7. On success, download stage35_results_JOBID.tar.gz from the HPC home/project directory using MobaXterm's SFTP panel. The archive contains the executed notebook and master_outputs files.

Notes:
- The notebook downloads burgers_shock.mat and allen_cahn.mat from GitHub if they are not present locally and internet access is available. If the job fails at the reference-solution download, obtain those exact files through an approved machine with internet access and upload them into your project/submission directory next to the notebook before retrying. The job script copies these files into each run directory. The Allen-Cahn file is checksum-verified by the notebook.
- The notebook also optionally downloads official_soap.py for an external parity check. Its internal fallback remains available if the module cannot be fetched.
- Job logs stay in the submission directory as stage35_JOBID.out and stage35_JOBID.err.
- The tar.gz download via MobaXterm goes to the lab PC. If you need it on your personal PC, transfer it from the lab PC using UltraViewer's file-transfer feature or an institution-approved storage method.
- The HPC manual says compute jobs must be submitted through Slurm and that user data are not backed up. Back up the result archive after downloading.
