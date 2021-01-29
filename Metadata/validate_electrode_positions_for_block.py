import numpy as np
import pandas as pd


# Options
n_rows_to_check = 10
seed = 168345

rng = np.random.default_rng(seed)  # can be called without a seed
rng.random()

# Load data to check
df = pd.read_csv('Metadata/Block_Table_2021_01_29_extended.csv')

# For each check
for i in range(0, n_rows_to_check):

    # Get details of random block, hemisphere and channel
    row_idx = rng.integers(0, df.shape[0])
    ferret = df.loc[row_idx, 'Ferret']
    block = df.loc[row_idx,'Block']
    chan = rng.integers(0, 32)

    if rng.integers(0, 2) > 0:
        hemisphere = 'Left'
    else:
        hemisphere = 'Right'

    test_value = df.loc[row_idx, hemisphere[0]+str(chan)]

    # Ask the user to go find details of the relevant depth (while remaining blind)
    print(f"\n{ferret}\t{block}\t{hemisphere}\tC{chan:02d}")

    txt = input("What do you think the depth should be? (to 3 decimal places)  ")

    response_value = float(txt)

    # Give feedback
    if response_value == test_value:
        print(f"Correct! You said {response_value}, the file said {test_value}")
    else:
        print(f"No, sorry... You said {response_value}, the file said {test_value}")
