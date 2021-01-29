'''

Generates JSON files for each recording site with list of blocks

Stephen Town - Oct 2020
'''

import json   
import os
import numpy as np
import pandas as pd
from pathlib import Path

# Globals
dirs = {
    'csv': 'C:/Analysis/Electrode Positions/CSV',
    'json': 'C:/Analysis/Electrode Positions/JSON',
    'blockTables': ['E:/UCL_Behaving/Block_Table.csv', 'F:/UCL_Behaving/Block_Table.csv']
}


def load_block_tables(dirs):
    
    if len(dirs['blockTables']) == 2:

        df_1 = pd.read_csv( dirs['blockTables'][0])
        df_2 = pd.read_csv( dirs['blockTables'][1])
        
        df = pd.concat([df_1, df_2])
        df = df.drop_duplicates() 

        df['datetime'] = pd.to_datetime(df['datetime'])

        return df


def load_positions(file_path, file_name):

    df = pd.read_csv( os.path.join(file_path, file_name))        

    df['depth'] = np.round(df['Position'] - df['Zero'], 3)
    df['start_dt'] = pd.to_datetime(df[['Year', 'Month', 'Day']])

    df = df.drop(['Year', 'Month', 'Day'], axis=1)

    return df


def write_as_json(file_path, dict, ID, hemisphere):
       
    # Convert timestamps and durations
    dict['start_dt'] = dict['start_dt'].ctime()

    if pd.isnull(dict['end_dt']):
        dict['end_dt'] = 0
        dict['duration'] = 0
    else:
        dict['end_dt'] = dict['end_dt'].ctime()
        dict['duration'] = dict['duration'].days
        
    # Write file
    file_name = f"{ID}_{hemisphere}{dict['Channel']:02d}_{dict['depth']:.3f}mm.json"
    file_path = os.path.join(file_path, file_name)

    with open(file_path, 'w+') as outfile:
        json.dump(dict, outfile, indent=3)


def create_jsons(dirs, df, ID, hemisphere, blocks):
    
    # For each channel
    for chan, c_data in df.groupby('Channel'):

        c_data = c_data.sort_values(['start_dt', 'Position'], ascending=[True, False])
        c_data['end_dt'] = c_data['start_dt'].shift(-1)
        c_data['duration'] = c_data['end_dt'] - c_data['start_dt']

        # For each site
        for site, site_data in c_data.iterrows():           

            if site_data['duration'].days == 0:  # Skip depths that weren't 
                continue

            site_dict = site_data.to_dict()

            idx = blocks['datetime'] >= site_data['start_dt'] & blocks['datetime'] < site_data['end_dt']

            write_as_json(dirs['json'], site_dict, ID, hemisphere)
    

def main():

    block_table = load_block_tables(dirs)

    # For each electrode moving file
    for file in Path(dirs['csv']).glob('*.csv'):

        ID = file.name[0:5]
        hemisphere = file.name[6]

        pos_table = load_positions(dirs['csv'], file)       

        create_jsons(dirs, pos_table, ID, hemisphere, block_table)


if __name__ == "__main__":
    main()
