'''


Note that sites are named using electrode number on the warp array 
(not the recorded channel on the MCS system)

Stephen Town - 30 Jan 2021
'''

import h5py
import pandas as pd
from pathlib import Path


vars_to_keep = ['Block', 'datetime']
save_dir = Path('/home/stephen/Github/Neural_Data_Tools/Metadata/site_blocks')


def write_sites_as_csv(ferret, hemipshere, electrode, f_data):

    electrode_name = [hemipshere + str(electrode)]
    electrode_data = f_data[vars_to_keep + electrode_name]

    for depth, site_data in electrode_data.groupby(electrode_name):

                                        
        site_name = "%s_%s%02d_%.3f.csv" % (ferret[0:5], hemipshere, electrode, depth)

        site_data.drop(electrode_name, axis=1, inplace=True)
        site_data.to_csv( str(save_dir / site_name), index=False)


def main():

    # Load data to check
    df = pd.read_csv('Metadata/Block_Table_2021_01_29_extended.csv')

    # For each ferret and electrode in an array
    for ferret, f_data in df.groupby('Ferret'):
        for electrode in range(0, 32):

            write_sites_as_csv(ferret, 'L', electrode, f_data)
            write_sites_as_csv(ferret, 'R', electrode, f_data)


if __name__ == "__main__":
    main()
    

