import numpy as np
import pandas as pd
from scipy import stats

# --- Load sector-scale discharge ---

D = pd.read_csv('./out/sector_D.csv', index_col=0, parse_dates=True)

# --- Mean, standard deviation, coefficient of variation ---

out = pd.DataFrame(index=D.columns)
out.index.name = 'sector'
out['D_mean_Gt_yr'] = D.mean()
out['D_std_Gt_yr']  = D.std()
out['D_cv']         = out['D_std_Gt_yr'] / out['D_mean_Gt_yr']

# --- Linear trend from annual means ---

def annual_means(ts, min_months=10):
    """Annual means, dropping years with fewer than min_months of data."""
    grp = ts.groupby(ts.index.year)
    return grp.mean()[grp.count() >= min_months]

def lintrend(years, values):
    slope, intercept, _, p, _ = stats.linregress(years, values)
    return slope, intercept, p

records = []
for sector in D.columns:
    ann = annual_means(D[sector].dropna())
    if len(ann) < 5:
        records.append({'sector': sector, 'trend_Gt_yr_dec': np.nan, 'trend_p': np.nan})
        continue
    years = np.array(ann.index, dtype=float)
    slope, intercept, p = lintrend(years, ann.values)
    records.append({'sector': sector, 'trend_Gt_yr_dec': slope * 10, 'trend_p': p})

out = out.join(pd.DataFrame(records).set_index('sector'))

out.to_csv('./out/sector_variability.csv', float_format='%.6f')

print(f"Written {len(out)} sectors to out/sector_variability.csv\n")
print("Sectors ranked by trend [Gt yr-1 dec-1]:")
print(out.sort_values('trend_Gt_yr_dec', ascending=False).to_string())
