import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns

# Load data to check
df = pd.read_csv('Block_Table_2021_01_29_extended.csv')

df.drop(['Ferret','Block','datetime'], axis=1, inplace=True)

depths = df.to_numpy()

print(depths.shape)

ax = sns.heatmap(depths)

plt.show()