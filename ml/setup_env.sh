python3 -m pip install --break-system-packages --quiet scipy 2>&1 | tail -3
python3 -c 'import scipy, numpy; print("scipy", scipy.__version__, "numpy", numpy.__version__)'
