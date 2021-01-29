'''

Block table is a csv table containing metadata on the subject, name and date of blocks of data recorded in a project.

Each project involves testing subjects across multiple sessions, with a block recorded for every session. 
On some sessions, neural data is also recorded from electrodes at multiple sites in the brain.

Some blocks 



We want to extend th

Stephen Town - 29 Jan 2021
'''

from collections import defaultdict
import numpy as np
from pathlib import Path
import pandas as pd

block_table_path = 'Metadata/Block_Table_2021_01_29.csv'
e_pos_path = Path('ElectrodePositions/Data/csv')


def load_electrode_data(e_pos_path):    

    pos_data = []                                      # Load each data frame and concatenate

    for pos_file in e_pos_path.glob('*.csv'):      

        pf = pd.read_csv( str(pos_file))

        pf['F_num'] = int(pos_file.name[1:5])           #<- we could also add brain region and cortical field here 
        pf['Hemisphere'] = pos_file.name[6:7]
                                
        pos_data.append( pf)
    
    pos_data = pd.concat( pos_data)
    
    pos_data['Date'] = pd.to_datetime( pos_data[['Year','Month','Day']])            # Make date one column
    pos_data = pos_data[['F_num','Hemisphere','Channel','Date','Zero','Position']]  # Reorder to make pretty
    pos_data['Depth'] = pos_data['Position'] - pos_data['Zero']                     # Recalculate depth (as may be missing in some files)

    return pos_data


def get_first_movement( pos_data):

    grouped = pos_data.groupby(['F_num'])
    first_movement = defaultdict(list)

    for group_name, group in grouped:

        first_movement['f_num'].append( group_name)
        first_movement['date'].append( group['Date'].min())
        
    first_movement['date'] = pd.to_datetime(first_movement['date'])

    return pd.DataFrame.from_dict(first_movement)
    

def rm_data_before_implant( block_table, first_move):

    block_table['datetime'] = pd.to_datetime(block_table['datetime'])
    block_table['f_num'] = block_table['Ferret'].str[1:5].astype('int')  # Get unique identifier for each ferret    

    all_data = []

    for _, row in first_move.iterrows():
        
        ferret_data = block_table[ block_table['f_num'] == row['f_num']]
        ferret_data = ferret_data[ ferret_data['datetime'] > row['date']]
        
        all_data.append(ferret_data)

    return pd.concat( all_data)


def crossref_electrode_positions( block_table, electrode_positions, nchans=32):
    
    L_depth = np.zeros((block_table.shape[0], nchans))
    R_depth = np.zeros((block_table.shape[0], nchans))
    block_table.reset_index(inplace=True)

    for idx, block in block_table.iterrows():

        block_pos = electrode_positions[(electrode_positions['F_num'] == block['f_num']) & (electrode_positions['Date'] < block['datetime'])]

        for chan in range(0, nchans):
            
            chan_pos = block_pos[(block_pos['Channel'] == chan)]

            L_data = chan_pos[(chan_pos['Hemisphere'] == 'L')]
            R_data = chan_pos[(chan_pos['Hemisphere'] == 'R')]

            if L_data.shape[0] > 0:
                L_depth[idx, chan] = L_data['Depth'].min()
            
            if R_data.shape[0] > 0:
                R_depth[idx, chan] = R_data['Depth'].min()

    L_depth = pd.DataFrame( np.around(L_depth, decimals=3), columns=['L'+str(x) for x in range(0, nchans)])
    R_depth = pd.DataFrame( np.around(R_depth, decimals=3), columns=['R'+str(x) for x in range(0, nchans)])

    return pd.concat([block_table, L_depth, R_depth], axis=1)


def main():


    # Load block table
    block_table = pd.read_csv( block_table_path)
    print(block_table.shape)

    # Remove duplicates (this can happen naturally as the block table is built in stages over time, collecting metadata from
    # several disks. Owing to data management requirements data sometimes migrating between disks, meaning duplicates can arise)
    block_table.drop_duplicates(inplace=True)
    block_table.drop(['DateNum','Duration'], axis=1, inplace=True)
    print(block_table.shape)

    # Load electrode positions
    electrode_positions = load_electrode_data(e_pos_path)
    first_move = get_first_movement(electrode_positions)

    # Remove data for blocks before implantation
    block_table = rm_data_before_implant(block_table, first_move)
    print(block_table.shape)        
    
    # Cross reference electrode position
    block_table = crossref_electrode_positions( block_table, electrode_positions)     
    
    block_table.drop(['index','f_num'], axis=1, inplace=True)
    block_table.to_csv('Metadata/Block_Table_2021_01_29_extended.csv', index=False)


if __name__ == "__main__":
    main()
