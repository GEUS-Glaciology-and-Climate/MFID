import numpy as np
import pandas as pd

# --- Load sector-scale discharge ---

D = pd.read_csv('./out/sector_D.csv', index_col=0, parse_dates=True)

OMEGA = 2 * np.pi / 365.25  # one cycle per year

def fit_annual_harmonic(ts, min_months=10):
    """Fit D(t) = a0 + a1*cos(wt) + b1*sin(wt) separately for each calendar year.

    Rewriting a1*cos(wt) + b1*sin(wt) as R*cos(wt - phi) gives the amplitude
    R = hypot(a1, b1) and the day-of-year of the peak, phi/w, directly.
    Returns one row per year: amplitude [Gt yr-1], phase_doy, r2, n.
    """
    records = []
    for year, grp in ts.groupby(ts.index.year):
        grp = grp.dropna()
        if len(grp) < min_months:
            continue
        t = grp.index.dayofyear.values.astype(float)
        y = grp.values
        X = np.column_stack([np.ones_like(t), np.cos(OMEGA * t), np.sin(OMEGA * t)])
        coef, *_ = np.linalg.lstsq(X, y, rcond=None)
        a0, a1, b1 = coef
        amplitude = np.hypot(a1, b1)
        phase_doy = (np.arctan2(b1, a1) / OMEGA) % 365.25
        yhat = X @ coef
        ss_res = np.sum((y - yhat) ** 2)
        ss_tot = np.sum((y - y.mean()) ** 2)
        r2 = 1 - ss_res / ss_tot if ss_tot > 0 else np.nan
        records.append({'year': year, 'amplitude': amplitude, 'phase_doy': phase_doy,
                         'r2': r2, 'n': len(grp)})
    return pd.DataFrame(records).set_index('year')

def trend(years, values):
    """Linear trend, scaled to per-decade. Returns (slope_per_decade, p)."""
    from scipy import stats
    slope, _, _, p, _ = stats.linregress(years, values)
    return slope * 10, p

annual_records = []
summary_records = []

for sector in D.columns:
    ann = fit_annual_harmonic(D[sector])
    if len(ann) < 5:
        continue

    annual_records.append(ann.assign(sector=sector))

    amp_trend, amp_p = trend(ann.index.values, ann['amplitude'].values)

    # Unwrap phase across years before trending, so a peak crossing the Dec/Jan
    # boundary doesn't look like a ~365-day jump; this assumes the true
    # year-to-year shift in peak timing is well under half a year.
    phase_rad = ann['phase_doy'].values * OMEGA
    phase_unwrapped_days = np.unwrap(phase_rad) / OMEGA
    phase_trend, phase_p = trend(ann.index.values, phase_unwrapped_days)

    summary_records.append({
        'sector': sector,
        'amplitude_mean_Gt_yr': ann['amplitude'].mean(),
        'amplitude_trend_Gt_yr_dec': amp_trend,
        'amplitude_trend_p': amp_p,
        'phase_mean_doy': ann['phase_doy'].mean(),
        'phase_trend_days_dec': phase_trend,
        'phase_trend_p': phase_p,
        'r2_mean': ann['r2'].mean(),
        'n_years': len(ann),
    })

annual = pd.concat(annual_records).reset_index()
annual.to_csv('./out/sector_seasonality_annual.csv', index=False, float_format='%.6f')

summary = pd.DataFrame(summary_records).set_index('sector')
summary.to_csv('./out/sector_seasonality.csv', float_format='%.6f')

print(f"Written {len(summary)} sectors to out/sector_seasonality.csv\n")
print("Sectors ranked by amplitude trend [Gt yr-1 dec-1]:")
print(summary.sort_values('amplitude_trend_Gt_yr_dec', ascending=False).to_string())
print("\nSectors ranked by phase-shift trend [days dec-1] (positive = later in year):")
print(summary.sort_values('phase_trend_days_dec', ascending=False).to_string())
print("\nMean R^2 of the annual harmonic fit (lower = seasonal cycle is not well "
      "described by a single sinusoid):")
print(summary['r2_mean'].sort_values().to_string())
