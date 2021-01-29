'''

Block table is a csv table containing metadata on the subject, name and date of blocks of data recorded in a project.

Each project involves testing subjects across multiple sessions, with a block recorded for every session. 
On some sessions, neural data is also recorded from electrodes at multiple sites in the brain.

Some blocks 



We want to extend th

Stephen Town - 29 Jan 2021
'''

from pathlib import Path
import pandas as pd

block_table_path = 'Metadata/Block_Table_2021_01_29.csv'
e_pos_path = Path('ElectrodePositions/Data/csv')


# Remove ferrets for which no electrode positions exist
def filter_for_implanted_animals(bt):

    acceptable_f = []                                   # List ferrets with electrode data

    for pos_file in e_pos_path.glob('*.csv'):
        acceptable_f.append( pos_file.name[1:5])

    bt['f_num'] = bt['Ferret'].str[1:5]                 # Get unique identifier for each ferret
    bt = bt[bt['f_num'].isin( acceptable_f)]            # Filter
    
    return bt


def load_electrode_data(e_pos_path):    

    pos_data = []                                   

    for pos_file in e_pos_path.glob('*.csv'):

        pf = pd.read_csv( str(pos_file))

        pf['F_num'] = int(pos_file.name[1:5])
        pf['Hemisphere'] = pos_file.name[6:7]
                                
        pos_data.append( pf)
    
    pos_data = pd.concat( pos_data)
    
    pos_data['Date'] = pd.to_datetime( pos_data[['Year','Month','Day']])            # Make date one column
    pos_data = pos_data[['F_num','Hemisphere','Channel','Date','Zero','Position']]  # Reorder 
    pos_data['Depth'] = pos_data['Position'] - pos_data['Zero']                     # Recalculate depth (as may be missing in some files)

    return pos_data
    

def main():


    # Load block table
    bt = pd.read_csv( block_table_path)
    print(bt.shape)

    # Remove duplicates (this can happen naturally as the block table is built in stages over time, collecting metadata from
    # several disks. Owing to data management requirements data sometimes migrating between disks, meaning duplicates can arise)
    bt.drop_duplicates(inplace=True)
    print(bt.shape)

    # Remove data for animals with no electrode positions (i.e. those without moveable electrodes)
    bt = filter_for_implanted_animals(bt)
    print(bt.shape)

    # Load electrode positions
    e_pos = load_electrode_data(e_pos_path)


    # Remove data for blocks before implantation

    print([e_pos.head()])





if __name__ == "__main__":
    main()
