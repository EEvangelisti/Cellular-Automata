#! /bin/bash

python3 -m venv plots
source plots/bin/activate

python -m pip install --upgrade pip
python -m pip install -q numpy matplotlib

python plot_trajectories.py "$1"

deactivate
