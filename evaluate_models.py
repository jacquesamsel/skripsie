import pathlib
import os

ITERATIONS_TO_EVAL = [100, 200, 300, 400, 500, 600]

model_names = [model for model in os.listdir("checkpoints") if not model.startswith("rnn_")]


checkpoints = [
    (model_name, iteration) for model_name in model_names for iteration in ITERATIONS_TO_EVAL
]



if __name__ == "__main__":
    for model_name, iteration in checkpoints:
        model_path = pathlib.Path("checkpoints") / model_name
        print(f"Evaluating model: {model_name}, iteration: {iteration}")
        os.system(f"python evaluate_model.py --model_path {model_path} --iteration {iteration}")