import pandas as pd
from tensorboard.backend.event_processing.event_file_loader import EventFileLoader
from tensorboard.util import tensor_util


def load_file(args):
    path, dir_name, tags_to_include = args  # tags_to_include: set or None
    steps, tags, values, times = [], [], [], []
    for event in EventFileLoader(path).Load():
        for v in event.summary.value:
            if tags_to_include is not None and v.tag not in tags_to_include:
                continue  # skip before any conversion work
            if v.HasField("simple_value"):
                val = v.simple_value
            elif v.HasField("tensor") and v.metadata.plugin_data.plugin_name == "scalars":
                val = tensor_util.make_ndarray(v.tensor).item()
            else:
                continue
            steps.append(event.step)
            tags.append(v.tag)
            values.append(val)
            times.append(event.wall_time)
    return pd.DataFrame({
        "step": steps, "tag": tags, "value": values,
        "wall_time": times, "dir_name": dir_name,
    })