import argparse
import concurrent.futures
import multiprocessing as mp
import os
import pickle
from time import sleep
from typing import List

import numpy as np
import torch
from audiodiffusion.audio_encoder import AudioEncoder
from tqdm import tqdm


def encode_file(model, mp3_file, dir) -> List[np.ndarray]:
    """
    Encode MP3 file as list of MP3ToVecs.

    Args:
        model (torch.nn.Module): MP3Tovec model.
        mp3_file (str): Filename of MP3.
        dir (str): Directory of MP3 files.

    Returns:
        List[np.ndarray]: List of MP3ToVec vectors
    """
    return model.encode([os.path.join(dir, mp3_file)], pool=None)[0].cpu().numpy()


def main():
    """
    Main function for the calc_mp3tovecs script.

    Encodes a directory of MP3 files as a dictionary of lists of MP3ToVec vectors

    Ags:
        --max_workers (int): Maximum number of cores to use. Default is the number of cores on the machine.
        --mp3tovec_model_file (str): Path to the MP3ToVec model file. Default is "models/mp3tovec.ckpt".
        --mp3tovecs_file (str): Path to the output file where the MP3ToVec vectors will be saved. Default is "models/mp3tovecs.p".
        --mp3s_dir (str): Path to the directory containing the MP3 files to be encoded. Default is "previews".
        --recursive (bool): Whether to recursively search for MP3 files in subdirectories. Default is False.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--max_workers",
        type=int,
        default=os.cpu_count() if os.cpu_count() is not None else 1,
        help="Maximum number of cores to use",
    )
    parser.add_argument(
        "--mp3tovec_model_file",
        type=str,
        default="models/mp3tovec.ckpt",
        help="MP3ToVec model file",
    )
    parser.add_argument(
        "--mp3tovecs_file",
        type=str,
        default="models/mp3tovecs.p",
        help="Mp3ToVecs output file",
    )
    parser.add_argument(
        "--mp3s_dir",
        type=str,
        default="previews",
        help="Directory of MP3 files",
    )
    parser.add_argument(
        "--recursive",
        type=bool,
        default=False,
        help="Process MP3s in subdirectories recursively",
    )
    parser.add_argument(
        "--save_every",
        type=int,
        default=1000,
        help="Save MP3ToVecs every N MP3s",
    )
    parser.add_argument(
        "--mp3s_dir_abs",
        type=str,
        default=None,
        help="Absolute path to the directory of MP3 files",
    )
    args = parser.parse_args()

    model = AudioEncoder()
    model.load_state_dict(
        {
            k.replace("model.", ""): v
            for k, v in torch.load(args.mp3tovec_model_file)["state_dict"].items()
        }
    )

    mp3tovecs = (
        pickle.load(open(args.mp3tovecs_file, "rb"))
        if os.path.exists(args.mp3tovecs_file)
        else {}
    )

    if args.recursive:
        formats = set([".mp3", ".wav", ".m4a", ".flac"])
        mp3_files_abs = [
            os.path.join(root, file)
            for root, _, files in os.walk(args.mp3s_dir)
            for file in files
            if file[file.rfind(".") :].lower() in formats
        ]
        mp3_files_rel = [
            os.path.relpath(file, args.mp3s_dir_abs or args.mp3s_dir)
            for file in mp3_files_abs
        ]
    else:
        mp3_files_abs = [
            os.path.join(args.mp3s_dir, file) for file in os.listdir(args.mp3s_dir)
        ]
        mp3_files_rel = os.listdir(args.mp3s_dir)

    torch.multiprocessing.set_start_method("spawn")
    with concurrent.futures.ProcessPoolExecutor(
        max_workers=args.max_workers
    ) as executor:
        futures = {
            executor.submit(encode_file, model, file_abs, ""): file_rel
            for file_abs, file_rel in tqdm(
                zip(mp3_files_abs, mp3_files_rel), desc="Setting up jobs"
            )
            if file_rel not in mp3tovecs and sleep(1e-4) is None
        }
        for i, future in enumerate(
            tqdm(
                concurrent.futures.as_completed(futures),
                total=len(futures),
                desc="Encoding MP3s",
            )
        ):
            mp3_file = futures[future]
            try:
                mp3tovecs[mp3_file] = future.result()
                if (i + 1) % args.save_every == 0:
                    pickle.dump(mp3tovecs, open(args.mp3tovecs_file, "wb"))
            except KeyboardInterrupt:
                break
            except Exception:
                print(f"Skipping {mp3_file}")

    pickle.dump(mp3tovecs, open(args.mp3tovecs_file, "wb"))


if __name__ == "__main__":
    main()
