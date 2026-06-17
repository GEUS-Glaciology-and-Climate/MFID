import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from adjust_spines import adjust_spines as adj

REGION_COLORS = {
    'NO': '#e41a1c', 'NE': '#377eb8', 'CE': '#4daf4a',
    'SE': '#984ea3', 'SW': '#ff7f00', 'CW': '#a65628', 'NW': '#f781bf'
}

# --- Load data ---
var = pd.read_csv('./out/catchment_variability.csv', index_col=0)
D_c     = pd.read_csv('./out/catchment_D.csv',     index_col=0, parse_dates=True)
D_vel_c = pd.read_csv('./out/catchment_D_vel.csv', index_col=0, parse_dates=True)
D_th_c  = pd.read_csv('./out/catchment_D_th.csv',  index_col=0, parse_dates=True)

var['region'] = var.index.str.split('___').str[0]
var['name']   = var.index.str.split('___').str[1]

# ============================================================
# Figure 1: Mean discharge vs CV — where is variability large?
# ============================================================

fig1, ax = plt.subplots(figsize=(7, 5))
adj(ax, ['left', 'bottom'])

for region, grp in var.groupby('region'):
    normal = grp[~grp['large_cov']]
    flagged = grp[grp['large_cov']]
    ax.scatter(normal['D_mean_Gt_yr'], normal['D_cv'],
               color=REGION_COLORS[region], label=region,
               s=25, alpha=0.8, zorder=3)
    ax.scatter(flagged['D_mean_Gt_yr'], flagged['D_cv'],
               color=REGION_COLORS[region],
               marker='*', s=120, edgecolors='k', linewidths=0.4,
               zorder=5)

for _, row in var[var['large_cov']].iterrows():
    ax.annotate(row['name'].replace('_', ' '),
                xy=(row['D_mean_Gt_yr'], row['D_cv']),
                xytext=(5, 2), textcoords='offset points',
                fontsize=6.5)

ax.set_xscale('log')
ax.set_xlabel('Mean discharge [Gt yr$^{-1}$]')
ax.set_ylabel('Coefficient of variation')
ax.legend(title='Region', fontsize=8, frameon=False,
          handletextpad=0.3, borderpad=0)
fig1.tight_layout()
fig1.savefig('./figs/variability_scatter.png', dpi=300, bbox_inches='tight')
plt.close(fig1)

# ============================================================
# Figure 2: Variance decomposition for top 30 by mean discharge
# ============================================================

top30 = var.nlargest(30, 'D_mean_Gt_yr').sort_values('D_mean_Gt_yr', ascending=True)

fig2, axes = plt.subplots(1, 2, figsize=(11, 8),
                           gridspec_kw={'width_ratios': [3, 1]})

ax_bar   = axes[0]
ax_dmean = axes[1]
adj(ax_bar, ['left', 'bottom'])
adj(ax_dmean, ['bottom'])

y      = np.arange(len(top30))
labels = [n.replace('_', ' ') for n in top30['name']]

# Stacked: frac_vel (blue) then frac_th (green)
# Bars extending past 1.0 → negative covariance; falling short → positive covariance
ax_bar.barh(y, top30['frac_vel'],                       color='#1f78b4', label='Velocity')
ax_bar.barh(y, top30['frac_th'], left=top30['frac_vel'], color='#33a02c', label='Thickness')
ax_bar.axvline(1.0, color='k', linewidth=0.8, linestyle='--', alpha=0.6)

ax_bar.set_yticks(y)
ax_bar.set_yticklabels(labels, fontsize=7)
ax_bar.set_xlabel('Fraction of total variance')
ax_bar.set_xlim(0, 1.15)
ax_bar.legend(fontsize=8, frameon=False, loc='lower right')

# Bold labels for large_cov catchments
ticklabels = ax_bar.get_yticklabels()
for i, (idx, row) in enumerate(top30.iterrows()):
    if row['large_cov']:
        ticklabels[i].set_fontweight('bold')

# Right panel: mean discharge coloured by region
colors_right = [REGION_COLORS[r] for r in top30['region']]
ax_dmean.barh(y, top30['D_mean_Gt_yr'], color=colors_right, alpha=0.85)
ax_dmean.set_yticks(y)
ax_dmean.set_yticklabels([])
ax_dmean.set_xlabel('Mean discharge\n[Gt yr$^{-1}$]')

# Region colour legend on right panel
from matplotlib.patches import Patch
handles = [Patch(color=c, label=r) for r, c in REGION_COLORS.items()]
ax_dmean.legend(handles=handles, fontsize=7, frameon=False,
                loc='lower right', handlelength=1)

fig2.tight_layout()
fig2.savefig('./figs/variability_decomp.png', dpi=300, bbox_inches='tight')
plt.close(fig2)

# ============================================================
# Figure 3: Time series for the 5 large-covariance catchments
# ============================================================

flagged = var[var['large_cov']].sort_values('frac_cov')
n = len(flagged)

fig3, axes = plt.subplots(n, 1, figsize=(9, 3 * n), sharex=True)

for ax, (cat, row) in zip(axes, flagged.iterrows()):
    adj(ax, ['left', 'bottom'])
    name = row['name'].replace('_', ' ')

    ax.plot(D_c.index,     D_c[cat],     color='k',       linewidth=1.5, label='Total D')
    ax.plot(D_vel_c.index, D_vel_c[cat], color='#1f78b4', linewidth=1.0,
            linestyle='--', label='Velocity only')
    ax.plot(D_th_c.index,  D_th_c[cat],  color='#33a02c', linewidth=1.0,
            linestyle=':',  label='Thickness only')

    fc = row['frac_cov']
    sign = '+' if fc >= 0 else '−'
    ax.set_title(f"{name}  (frac_cov = {sign}{abs(fc):.2f})", fontsize=9, loc='left')
    ax.set_ylabel('D [Gt yr$^{-1}$]', fontsize=8)

axes[0].legend(fontsize=8, frameon=False, ncol=3, loc='upper left')
axes[-1].set_xlabel('Date')
axes[-1].xaxis.set_major_locator(mdates.YearLocator())

fig3.tight_layout()
fig3.savefig('./figs/variability_ts.png', dpi=300, bbox_inches='tight')
plt.close(fig3)

print("Saved:")
print("  figs/variability_scatter.png")
print("  figs/variability_decomp.png")
print("  figs/variability_ts.png")

# ============================================================
# Figure 4: GIS-wide and top-5 catchment discharge vs. mean
# ============================================================

D_gis = pd.read_csv('./out/GIS_D.csv', index_col=0, parse_dates=True).squeeze()
D_cat = pd.read_csv('./out/catchment_D.csv', index_col=0, parse_dates=True)

top5 = var.nlargest(5, 'D_mean_Gt_yr')

# One panel per row: GIS total on top, then 5 catchments
fig4, axes = plt.subplots(6, 1, figsize=(10, 13), sharex=True)

C_POS = '#e31a1c'   # red  — above mean
C_NEG = '#1f78b4'   # blue — below mean

def plot_variability_panel(ax, ts, label, mean, cv):
    adj(ax, ['left', 'bottom'])
    ax.axhline(mean, color='k', linewidth=0.8, linestyle='--', alpha=0.5, zorder=2)
    ax.fill_between(ts.index, ts.values, mean,
                    where=(ts.values >= mean), color=C_POS, alpha=0.45, zorder=1)
    ax.fill_between(ts.index, ts.values, mean,
                    where=(ts.values < mean), color=C_NEG, alpha=0.45, zorder=1)
    ax.plot(ts.index, ts.values, color='k', linewidth=0.7, zorder=3)
    ax.set_title(label, fontsize=9, loc='left', pad=3)
    ax.set_ylabel('D [Gt yr$^{-1}$]', fontsize=8)
    ax.text(0.99, 0.95,
            f"$\\bar{{D}}$ = {mean:.1f} Gt yr$^{{-1}}$,  CV = {cv:.2f}",
            transform=ax.transAxes, ha='right', va='top', fontsize=7.5)

# GIS total
gis_mean = D_gis.mean()
gis_cv   = D_gis.std() / gis_mean
plot_variability_panel(axes[0], D_gis, 'Ice sheet total', gis_mean, gis_cv)

# Top 5 catchments
for ax, (cat, row) in zip(axes[1:], top5.iterrows()):
    ts     = D_cat[cat]
    mean   = row['D_mean_Gt_yr']
    cv     = row['D_cv']
    region = row['region']
    name   = row['name'].replace('_', ' ')
    plot_variability_panel(ax, ts, f"{name}  ({region})", mean, cv)

axes[-1].set_xlabel('Date')
axes[-1].xaxis.set_major_locator(mdates.YearLocator())

# Shared legend at top
from matplotlib.patches import Patch
axes[0].legend(
    handles=[Patch(color=C_POS, alpha=0.6, label='Above mean'),
             Patch(color=C_NEG, alpha=0.6, label='Below mean')],
    fontsize=8, frameon=False, ncol=2, loc='upper left')

fig4.tight_layout()
fig4.subplots_adjust(hspace=0.45)
fig4.savefig('./figs/variability_overview.png', dpi=300, bbox_inches='tight')
plt.close(fig4)
print("  figs/variability_overview.png")

# ============================================================
# Figure 5: Trend decomposition — annual means, vel vs. th
# ============================================================

from scipy import stats

D_vel_gis = D_vel_c.sum(axis=1, min_count=1)
D_th_gis  = D_th_c.sum(axis=1,  min_count=1)

def annual_means(ts, min_months=10):
    """Annual means, dropping years with fewer than min_months of data."""
    grp = ts.groupby(ts.index.year)
    return grp.mean()[grp.count() >= min_months]

def lintrend(years, values):
    slope, intercept, _, p, _ = stats.linregress(years, values)
    return slope, intercept, p

def sig_stars(p):
    return '***' if p < 0.001 else ('**' if p < 0.01 else ('*' if p < 0.05 else 'n.s.'))

def plot_trend_panel(ax, D_mon, Dv_mon, Dt_mon, label):
    adj(ax, ['left', 'bottom'])

    D_ann  = annual_means(D_mon)
    Dv_ann = annual_means(Dv_mon)
    Dt_ann = annual_means(Dt_mon)

    years = sorted(set(D_ann.index) & set(Dv_ann.index) & set(Dt_ann.index))
    D_ann, Dv_ann, Dt_ann = D_ann.loc[years], Dv_ann.loc[years], Dt_ann.loc[years]
    x = np.array(years, dtype=float)

    D_slope,  D_icept,  D_p  = lintrend(x, D_ann.values)
    Dv_slope, Dv_icept, Dv_p = lintrend(x, Dv_ann.values)
    Dt_slope, Dt_icept, Dt_p = lintrend(x, Dt_ann.values)

    # Plot as anomalies from D mean so all three series share a zero baseline
    d_mean = D_ann.mean()
    x_dt = pd.to_datetime([f"{y}-07-01" for y in years])

    ax.axhline(0, color='k', linewidth=0.5, alpha=0.4)
    ax.plot(x_dt, D_ann  - d_mean, 'ko-', ms=4, lw=1,   label='Total D', zorder=4)
    ax.plot(x_dt, Dv_ann - d_mean, 'o-', color='#1f78b4', ms=3, lw=1, label='Vel only', zorder=3)
    ax.plot(x_dt, Dt_ann - d_mean, 'o-', color='#33a02c', ms=3, lw=1, label='Thk only',  zorder=3)

    ax.plot(x_dt, D_slope  * x + D_icept  - d_mean, 'k--',              lw=1.2, zorder=5)
    ax.plot(x_dt, Dv_slope * x + Dv_icept - d_mean, '--', color='#1f78b4', lw=1.2, zorder=5)
    ax.plot(x_dt, Dt_slope * x + Dt_icept - d_mean, '--', color='#33a02c', lw=1.2, zorder=5)

    ax.set_title(label, fontsize=9, loc='left', pad=3)
    ax.set_ylabel('D anomaly\n[Gt yr$^{-1}$]', fontsize=8)

    # Trend rates in Gt/yr per decade
    ax.text(0.99, 0.03,
            f"Trend:  total {D_slope*10:+.2f} / vel {Dv_slope*10:+.2f} / thk {Dt_slope*10:+.2f}"
            f"  Gt yr$^{{-1}}$ dec$^{{-1}}$  ({sig_stars(D_p)})",
            transform=ax.transAxes, ha='right', va='bottom', fontsize=7,
            bbox=dict(facecolor='white', alpha=0.8, edgecolor='none', pad=1))

fig5, axes = plt.subplots(6, 1, figsize=(10, 13), sharex=True)

plot_trend_panel(axes[0], D_gis, D_vel_gis, D_th_gis, 'Ice sheet total')
axes[0].legend(fontsize=8, frameon=False, ncol=3, loc='lower left')

for ax, (cat, row) in zip(axes[1:], top5.iterrows()):
    name   = row['name'].replace('_', ' ')
    region = row['region']
    plot_trend_panel(ax, D_cat[cat], D_vel_c[cat], D_th_c[cat],
                     f"{name}  ({region})")

axes[-1].set_xlabel('Year')
axes[-1].xaxis.set_major_locator(mdates.YearLocator())

fig5.tight_layout()
fig5.subplots_adjust(hspace=0.45)
fig5.savefig('./figs/variability_trend.png', dpi=300, bbox_inches='tight')
plt.close(fig5)
print("  figs/variability_trend.png")

# ============================================================
# Figure 6: Ranked catchment trends — who drives the increase?
# ============================================================

# Compute annual mean trend for every catchment
records = []
for cat in D_cat.columns:
    if cat not in var.index:
        continue
    ann = annual_means(D_cat[cat].dropna())
    if len(ann) < 5:
        continue
    x = np.array(ann.index, dtype=float)
    slope, _, p = lintrend(x, ann.values)
    records.append({
        'catchment': cat,
        'region':    cat.split('___')[0],
        'name':      cat.split('___')[1].replace('_', ' '),
        'trend':     slope * 10,   # Gt/yr per decade
        'p':         p,
        'D_mean':    var.loc[cat, 'D_mean_Gt_yr'],
    })

trends = pd.DataFrame(records).set_index('catchment')

# Keep catchments large enough to be meaningful, then split pos/neg
trends = trends[trends['D_mean'] > 0.05]
pos = trends[trends['trend'] >= 0].nlargest(20, 'trend')
neg = trends[trends['trend'] <  0].nsmallest(20, 'trend')   # most negative first

display = pd.concat([pos, neg]).sort_values('trend', ascending=True)

fig6, ax = plt.subplots(figsize=(7, max(5, len(display) * 0.28)))
adj(ax, ['left', 'bottom'])

y   = np.arange(len(display))
bar_colors = [REGION_COLORS[r] for r in display['region']]

bars = ax.barh(y, display['trend'], color=bar_colors, alpha=0.85, edgecolor='none')

# Hatch negative bars so they stand out
for bar, (_, row) in zip(bars, display.iterrows()):
    if row['trend'] < 0:
        bar.set_hatch('///')
        bar.set_alpha(0.6)

# Significance markers on the bar ends
for i, (_, row) in enumerate(display.iterrows()):
    stars = sig_stars(row['p'])
    if stars != 'n.s.':
        xpos = row['trend'] + (0.02 if row['trend'] >= 0 else -0.02)
        ha   = 'left' if row['trend'] >= 0 else 'right'
        ax.text(xpos, i, stars, va='center', ha=ha, fontsize=6.5, color='k')

ax.axvline(0, color='k', linewidth=0.8)
ax.set_yticks(y)
ax.set_yticklabels(display['name'], fontsize=7)
ax.set_xlabel('Trend [Gt yr$^{-1}$ dec$^{-1}$]')
ax.set_title('Catchment discharge trends (top 20 positive, top 20 negative)',
             fontsize=9, loc='left')

# Region legend
from matplotlib.patches import Patch
handles = [Patch(color=c, label=r) for r, c in REGION_COLORS.items()
           if r in display['region'].values]
ax.legend(handles=handles, fontsize=7, frameon=False,
          loc='lower right', handlelength=1)

fig6.tight_layout()
fig6.savefig('./figs/variability_ranked_trends.png', dpi=300, bbox_inches='tight')
plt.close(fig6)
print("  figs/variability_ranked_trends.png")
