- *report/* Typst file etc can be found here
- *runs/* tensorboard logs from each run
- *results/* processed results
- *infer.py* run inference using a specific model that already exists
- *train.py* train a single model
- *hyperparameter_search.py* train many models
- *environment.py* instantiate & interface with environments
- *bench_perf.py* find environment + training params that optimise train throughput
- *visualize.py* visualise the observations (for debugging) e.g. LiDAR rays etc
- *trackgen.ipynb* visualise generation of tracks
- *lr_aux_heads.py* probe the model for its representation of the auxiliary targets
- *aux_head_regression_results.ipynb* visualise the probe results


Unfortunately, the code for the Unity environment is impractical to track in Git.