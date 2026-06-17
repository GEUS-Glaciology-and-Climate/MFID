import numpy as np
import pandas as pd

STARTDATE = pd.Timestamp('2014-10-01')
COV_THRESHOLD = 0.2  # flag catchments where |frac_cov| exceeds this

# --- Metadata and catchment labels ---

meta = pd.read_csv("./tmp/dat.csv", usecols=["err_2D", "sectors@Mouginot_2019", "bed@BedMachine"])
meta.rename(columns={'sectors@Mouginot_2019': 'catchments'}, inplace=True)

catchment_labels = {}
with open('./G/Mouginot_2019/cats/sectors') as f:
    for line in f:
        line = line.strip()
        if ':' in line:
            cat, name = line.split(':', 1)
            catchment_labels[int(cat)] = name
meta['catchments'] = meta['catchments'].map(catchment_labels)

# --- Velocity (pixel × time) ---

def parse_vel_col(c):
    return pd.Timestamp(f"{c[8:12]}-{c[13:15]}-{c[16:18]}")

vel = pd.read_csv("./tmp/dat.csv", usecols=lambda c: 'vel_eff' in c and 'ENVEO' in c)
vel.rename(columns=parse_vel_col, inplace=True)
vel.replace(0, np.nan, inplace=True)
vel.sort_index(axis=1, inplace=True)
vel = vel.interpolate(method='time', axis=1, limit_area='inside')
vel.ffill(axis=1, inplace=True)
vel.bfill(axis=1, inplace=True)
vel = vel.loc[:, vel.columns >= STARTDATE]

# --- Time-varying thickness (pixel × time) from saved DEM time series ---

dem_ts = pd.read_csv("./tmp/dem_ts.csv", index_col=0)
dem_ts.columns = pd.to_datetime(dem_ts.columns)
# align to the same timestamps as vel
dem_ts = dem_ts.reindex(columns=vel.columns)
th_ts = dem_ts.sub(meta['bed@BedMachine'].values, axis=0)

# --- Per-pixel scaling constant: pixel_width × area_correction × ice_density ---
# Units: vel [m yr-1] × th [m] × K → Gt yr-1
K = (200 * meta['err_2D'].values * 917 / 1e12)

# --- Time-mean velocity and thickness per pixel ---
vel_mean = vel.mean(axis=1)   # shape: n_pixels
th_mean  = th_ts.mean(axis=1) # shape: n_pixels

# --- Three discharge variants at pixel level ---
# Full: both vel and th vary with time
D_px     = (vel * th_ts).multiply(K, axis=0)
# Vel-only: thickness fixed at its time-mean
D_vel_px = vel.multiply(th_mean * K, axis=0)
# Th-only: velocity fixed at its time-mean
D_th_px  = th_ts.multiply(vel_mean * K, axis=0)

# --- Aggregate to catchment level ---
catchments = meta['catchments'].values
D_c     = D_px.groupby(catchments).sum()
D_vel_c = D_vel_px.groupby(catchments).sum()
D_th_c  = D_th_px.groupby(catchments).sum()

# --- Step 1: mean, standard deviation, coefficient of variation ---
out = pd.DataFrame(index=D_c.index)
out.index.name = 'catchment'
out['D_mean_Gt_yr'] = D_c.mean(axis=1)
out['D_std_Gt_yr']  = D_c.std(axis=1)
out['D_cv']         = out['D_std_Gt_yr'] / out['D_mean_Gt_yr']

# --- Step 2: Variance decomposition ---
# Var(D) = Var(D_vel) + Var(D_th) + residual
# The residual captures the covariance between velocity and thickness changes.
out['Var_total_Gt2'] = D_c.var(axis=1)
out['Var_vel_Gt2']   = D_vel_c.var(axis=1)
out['Var_th_Gt2']    = D_th_c.var(axis=1)
out['Var_cov_Gt2']   = out['Var_total_Gt2'] - out['Var_vel_Gt2'] - out['Var_th_Gt2']

out['frac_vel'] = out['Var_vel_Gt2'] / out['Var_total_Gt2']
out['frac_th']  = out['Var_th_Gt2']  / out['Var_total_Gt2']
out['frac_cov'] = out['Var_cov_Gt2'] / out['Var_total_Gt2']

# --- Step 3: flag catchments with large covariance contribution ---
out['large_cov'] = out['frac_cov'].abs() > COV_THRESHOLD

out.to_csv('./out/catchment_variability.csv', float_format='%.6f')

# Save per-catchment time series for vel-only and th-only (used by figures)
D_vel_c.T.to_csv('./out/catchment_D_vel.csv', index_label='Date')
D_th_c.T.to_csv('./out/catchment_D_th.csv',  index_label='Date')

print(f"Written {len(out)} catchments to out/catchment_variability.csv")

summary = out[['D_mean_Gt_yr', 'D_std_Gt_yr', 'D_cv', 'frac_vel', 'frac_th', 'frac_cov']]

print(f"\nTop 10 most variable catchments (by CV):")
print(summary.nlargest(10, 'D_cv').to_string())

n_large_cov = out['large_cov'].sum()
print(f"\nCatchments with |frac_cov| > {COV_THRESHOLD} ({n_large_cov} total):")
print(summary[out['large_cov']].sort_values('frac_cov', ascending=False).to_string())
