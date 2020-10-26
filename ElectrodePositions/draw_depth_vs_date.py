'''
Draw Electrode Depths

Downloads data directly from github url

Stephen Town - october 2020
'''

import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import pandas as pd


# Load data
file_name = 'F1808_Right.csv'
file_url = 'https://raw.githubusercontent.com/stephentown42/Neural_Data_Tools/master/ElectrodePositions/' + file_name

df = pd.read_csv(file_url)

df['Depth'] = df['Position'] - df['Zero']
df['start_dt'] = pd.to_datetime(df[['Year', 'Month', 'Day']])

dt = df['start_dt'].to_numpy()
xlim = (min(dt), max(dt))

# Create figure
plt.style.use('ggplot')
fig, ax = plt.subplots(1, 2, figsize=(8, 8))

years = mdates.YearLocator()   # every year
months = mdates.MonthLocator()  # every month
years_fmt = mdates.DateFormatter('%Y')

y = 0

for chan, c_data in df.groupby('Channel'):

    c_data = c_data.sort_values('start_dt')
    ax[0].plot(c_data['start_dt'], c_data['Depth'])

    c_data['end_dt'] = c_data['start_dt'].shift(-1)
    c_data.drop(c_data.tail(1).index, inplace=True)     # Ignore last movement (as duration is meaningless)

    c_data['duration'] = c_data['end_dt'] - c_data['start_dt']

    for index, row in c_data.iterrows():
        y += 1
        ax[1].barh(y, row['duration'].days)

ax[0].set_xlim(xlim)
ax[0].xaxis.set_major_locator(years)
ax[0].xaxis.set_major_formatter(years_fmt)
ax[0].xaxis.set_minor_locator(months)
ax[0].format_xdata = mdates.DateFormatter('%Y-%m-%d')
ax[0].set_xlabel('Date')
ax[0].set_ylabel('Depth (mm)')

ax[1].set_xlabel('Days')
ax[1].set_ylabel('Site')
ax[1].set_title(file_name)

plt.tight_layout()
plt.show()
