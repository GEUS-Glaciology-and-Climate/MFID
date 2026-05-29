import matplotlib.gridspec as gridspec
import numpy as np
import pandas as pd
from adjust_spines import adjust_spines as adj
import matplotlib.pyplot as plt
import datetime as dt

# plt.close(1)

fig = plt.figure(1, figsize=(9,5)) # w,h
fig.clf()

ax_D = fig.add_subplot(111)

adj(ax_D, ['left','bottom'])

D = pd.read_csv("./out/GIS_D.csv", index_col=0, parse_dates=True)
err = pd.read_csv("./out/GIS_err.csv", index_col=0, parse_dates=True)
coverage = pd.read_csv("./out/GIS_coverage.csv", index_col=0, parse_dates=True)

import xarray as xr
_ref = xr.open_dataset('https://thredds.geus.dk/thredds/dodsC/solid_ice_discharge/GIS.nc')
D_M2019 = _ref['discharge'].to_series().to_frame('Discharge [Gt yr-1]')
err_M2019 = _ref['err'].to_series().to_frame('Discharge Error [Gt yr-1]')

D_M2019 = D_M2019[(D_M2019.index > D.index[0]) & (D_M2019.index <= D.index[-1])]
err_M2019 = err_M2019[(err_M2019.index > err.index[0]) & (err_M2019.index <= err.index[-1])]

# | Color       |   R |   G |   B | hex     |
# |-------------+-----+-----+-----+---------|
# | light blue  | 166 | 206 | 227 | #a6cee3 |
# | dark blue   |  31 | 120 | 180 | #1f78b4 |
# | light green | 178 | 223 | 138 | #b2df8a |
# | dark green  |  51 | 160 |  44 | #33a02c |
# | pink        | 251 | 154 | 153 | #fb9a99 |
# | red         | 227 |  26 |  28 | #e31a1c |
# | pale orange | 253 | 191 | 111 | #fdbf6f |
# | orange      | 255 | 127 |   0 | #ff7f00 |
C1="#e31a1c" # red
C2="#1f78b4" # dark blue

MS=4

D_M2019.plot(ax=ax_D, marker='.', color=C2, label='')
D.plot(ax=ax_D, drawstyle='steps', color=C1, label='')

ax_D.fill_between(err.index, 
                  (D.values-err.values).flatten(), 
                  (D.values+err.values).flatten(), 
                  color=C1, alpha=0.25, label='')

ax_D.fill_between(err_M2019.index, 
                  (D_M2019.values-err_M2019.values).flatten(), 
                  (D_M2019.values+err_M2019.values).flatten(), 
                  color=C2, alpha=0.25, label='')

ax_D.legend(["PROMICE", "MFID"], framealpha=0)
ax_D.set_xlabel('Time [Years]')
ax_D.set_ylabel('Discharge [Gt yr$^{-1}$]')

import matplotlib.dates as mdates
ax_D.xaxis.set_major_locator(mdates.YearLocator())
ax_D.minorticks_off()
# ax_D.xaxis.set_tick_params(rotation=-90) #, ha="left", rotation_mode="anchor")
# for tick in ax_D.xaxis.get_majorticklabels():
#     tick.set_horizontalalignment("left")

plt.savefig('./figs/discharge_ts.png', transparent=False, bbox_inches='tight', dpi=300)
# plt.savefig('./figs/discharge_ts.pdf', box_inches='tight', dpi=300)

# disp = pd.DataFrame(data = {'D':D_day_year.values.flatten(), 'err':err_day_year.values.flatten()},
#                     index = D_day_year.index.year)
# disp.index.name = 'Year'
# disp

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# plt.close(1)

fig = plt.figure(1, figsize=(9,5)) # w,h
fig.clf()
# fig.set_tight_layout(True)


ax_D = fig.add_subplot(111)

from adjust_spines import adjust_spines as adj
adj(ax_D, ['left','bottom'])

D = pd.read_csv("./out/sector_D.csv", index_col=0, parse_dates=True)
err = pd.read_csv("./out/sector_err.csv", index_col=0, parse_dates=True)

D[['8.1','7.1']].plot(ax=ax_D, linewidth=3)
ax_D.fill_between(D.index,
                  D['8.1']-err['8.1'],
                  D['8.1']+err['8.1'], alpha=0.25)

ax_D.fill_between(D.index,
                  D['7.1']-err['7.1'],
                  D['7.1']+err['7.1'], alpha=0.25)


ax_D.set_ylim([0,120])
ax_D.set_ylabel("Discharge [Gt yr$^{-1}$]")
ax_D.set_xlabel("Date")

plt.savefig('./figs/discharge_ts_sectors.png', transparent=False, bbox_inches='tight', dpi=300)


fig1 = plt.figure(1, figsize=(9,5)) # w,h
fig1.clf()
ax_D1 = fig.add_subplot(111)

from adjust_spines import adjust_spines as adj
adj(ax_D1, ['left','bottom'])

D = pd.read_csv("./out/region_D.csv", index_col=0, parse_dates=True)
err = pd.read_csv("./out/region_err.csv", index_col=0, parse_dates=True)

D[['CE','CW','NE','NO','NW','SE','SW']].plot(ax=ax_D1, linewidth=3)

ax_D1.fill_between(D.index,
                  D['CE']-err['CE'],
                  D['CE']+err['CE'], alpha=0.25)

ax_D1.fill_between(D.index,
                  D['CW']-err['CW'],
                  D['CW']+err['CW'], alpha=0.25)

ax_D1.fill_between(D.index,
                  D['NE']-err['NE'],
                  D['NE']+err['NE'], alpha=0.25)

ax_D1.fill_between(D.index,
                  D['NO']-err['NO'],
                  D['NO']+err['NO'], alpha=0.25)

ax_D1.fill_between(D.index,
                  D['NW']-err['NW'],
                  D['NW']+err['NW'], alpha=0.25)

ax_D1.fill_between(D.index,
                  D['SE']-err['SE'],
                  D['SE']+err['SE'], alpha=0.25)

ax_D1.fill_between(D.index,
                  D['SW']-err['SW'],
                  D['SW']+err['SW'], alpha=0.25)

ax_D1.legend(loc=3)
ax_D1.set_ylim([0,170])
ax_D1.set_ylabel("Discharge [Gt yr$^{-1}$]")
ax_D1.set_xlabel("Date")


plt.savefig('./figs/discharge_ts_regions.png', transparent=False, bbox_inches='tight', dpi=300)
# # largest average for last year
# D_sort = D.resample('Y', axis='rows')\
#           .mean()\
#           .iloc[-1]\
#           .sort_values(ascending=False)

# LABELS={}
# # for k in D_sort.head(8).index: LABELS[k] = k
# # Use the last       ^ glaciers

# # Make legend pretty
# LABELS['JAKOBSHAVN_ISBRAE'] = 'Sermeq Kujalleq (Jakobshavn Isbræ)'
# LABELS['HELHEIMGLETSCHER'] = 'Helheim Gletsjer'
# LABELS['KANGERLUSSUAQ'] = 'Kangerlussuaq Gletsjer'
# LABELS['KOGE_BUGT_C'] = '(Køge Bugt C)'
# LABELS['ZACHARIAE_ISSTROM'] = 'Zachariae Isstrøm'
# LABELS['RINK_ISBRAE'] = 'Kangilliup Sermia (Rink Isbræ)'
# LABELS['NIOGHALVFJERDSFJORDEN'] = '(Nioghalvfjerdsbrae)'
# LABELS['PETERMANN_GLETSCHER'] ='Petermann Gletsjer'

# SYMBOLS={}
# SYMBOLS['JAKOBSHAVN_ISBRAE'] = 'o'
# SYMBOLS['HELHEIMGLETSCHER'] = 's'
# SYMBOLS['KANGERLUSSUAQ'] = 'v'
# SYMBOLS['KOGE_BUGT_C'] = '^'
# SYMBOLS['NIOGHALVFJERDSFJORDEN'] = 'v'
# SYMBOLS['RINK_ISBRAE'] = 's'
# SYMBOLS['ZACHARIAE_ISSTROM'] = 'o'
# SYMBOLS['PETERMANN_GLETSCHER'] ='^'

# MS=4
# Z=99
# for g in LABELS.keys(): # for each glacier
#     e = ax_D.errorbar(D.loc[:,g].index,
#                       D.loc[:,g].values,
#                       label=LABELS[g],
#                       fmt=SYMBOLS[g],
#                       mfc='none',
#                       ms=MS)
#     C = e.lines[0].get_color()
#     D_day_year.loc[:,g].plot(drawstyle='steps', linewidth=2,
#                              label='',
#                              ax=ax_D,
#                              alpha=0.75, color=C, zorder=Z)

#     for i,idx in enumerate(D.loc[:,g].index):
#         ax_D.errorbar(D.loc[:,g].index[i],
#                       D.loc[:,g].values[i],
#                       yerr=err.loc[:,g].values[i],
#                       alpha=coverage.loc[:,g].values[i],
#                       label='',
#                       ecolor='grey',
#                       mfc=C, mec=C,
#                       marker='o', ms=MS)


#     if g in ['NIOGHALVFJERDSFJORDEN', 'KANGERLUSSUAQ']: #, 'JAKOBSHAVN_ISBRAE']:
#         ax_coverage.plot(D.loc[:,g].index,
#                          coverage.loc[:,g].values*100,
#                          drawstyle='steps',
#                          # alpha=0.5,
#                          color=C)

# # yl = ax_D.get_ylim()

# ax_D.legend(fontsize=8, ncol=2, loc=(0.0, 0.82), fancybox=False, frameon=False)
# ax_D.set_xlabel('Time [Years]')
# ax_D.set_ylabel('Discharge [Gt yr$^{-1}$]')

# import matplotlib.dates as mdates
# ax_D.xaxis.set_major_locator(mdates.YearLocator())
# ax_D.xaxis.set_tick_params(rotation=-90)
# for tick in ax_D.xaxis.get_majorticklabels():
#     tick.set_horizontalalignment("left")

# ax_coverage.set_ylabel('Coverage [%]')
# ax_coverage.set_ylim([0,100])


#plt.savefig('./figs/discharge_ts_topfew.svg', transparent=True, bbox_inches='tight', dpi=300)

# plt.savefig('./figs/discharge_ts_topfew.pdf', transparent=True, bbox_inches='tight', dpi=300)

# Err_pct = (err_day_year / D_day_year*100).round().astype(np.int).astype(np.str)
# Err_pct = Err_pct[list(LABELS.keys())]
# tbl = D_day_year[list(LABELS.keys())].round().astype(np.int).astype(np.str) + ' (' + Err_pct+')'
# tbl.index = tbl.index.year.astype(np.str)
# tbl.columns = [_ + ' (%)' for _ in tbl.columns]
# tbl

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

CCI = pd.read_csv("./out/GIS_D.csv", index_col=0, parse_dates=True)\
        .rename({'Discharge [Gt yr-1]':'CCI'}, axis='columns')
ID = _ref['discharge'].to_series().rename('PROMICE').to_frame()

df = pd.merge(CCI,ID,how='outer', left_index=True, right_index=True).dropna()
# df['diff'] = df['PROMICE'] - df['CCI']
df.plot()

plt.savefig("./figs/this_v_M2019.png", dpi=300)
