import matplotlib.cm as cm
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from adjust_spines import adjust_spines as adj
from scipy import stats

# --- Load data ---

D    = pd.read_csv('./out/sector_D.csv',   index_col=0, parse_dates=True)
err  = pd.read_csv('./out/sector_err.csv', index_col=0, parse_dates=True)
var  = pd.read_csv('./out/sector_variability.csv', index_col=0)
var.index = var.index.astype(str)

GROUP_NAMES = {'1': 'NO', '2': 'NE', '3': 'CE', '4': 'SE',
               '5': 'S', '6': 'SW', '7': 'CW', '8': 'NW'}

SECTORS = list(D.columns)
GROUPS  = [s.split('.')[0] for s in SECTORS]
GROUP_IDS = sorted(set(GROUPS), key=int)
cmap = cm.get_cmap('tab10', len(GROUP_IDS))
GROUP_COLORS = {g: cmap(i) for i, g in enumerate(GROUP_IDS)}
SECTOR_COLORS = {s: GROUP_COLORS[g] for s, g in zip(SECTORS, GROUPS)}

def annual_means(ts, min_months=10):
    grp = ts.groupby(ts.index.year)
    return grp.mean()[grp.count() >= min_months]

def lintrend(years, values):
    slope, intercept, _, p, _ = stats.linregress(years, values)
    return slope, intercept, p

def sig_stars(p):
    return '***' if p < 0.001 else ('**' if p < 0.01 else ('*' if p < 0.05 else 'n.s.'))

# ============================================================
# Figure 1: Mean discharge vs CV — where is variability large?
# ============================================================

fig1, ax = plt.subplots(figsize=(7, 5))
adj(ax, ['left', 'bottom'])

for g in GROUP_IDS:
    grp = var[np.array(GROUPS) == g]
    ax.scatter(grp['D_mean_Gt_yr'], grp['D_cv'],
               color=GROUP_COLORS[g], label=GROUP_NAMES[g],
               s=35, alpha=0.85, zorder=3)

for sector, row in var.iterrows():
    ax.annotate(sector, xy=(row['D_mean_Gt_yr'], row['D_cv']),
                xytext=(5, 2), textcoords='offset points', fontsize=6.5)

ax.set_xscale('log')
ax.set_xlabel('Mean discharge [Gt yr$^{-1}$]')
ax.set_ylabel('Coefficient of variation')
ax.legend(title='Sector', fontsize=8, frameon=False,
          handletextpad=0.3, borderpad=0, ncol=2)
fig1.tight_layout()
fig1.savefig('./figs/sector_variability_scatter.png', dpi=300, bbox_inches='tight')
plt.close(fig1)

# ============================================================
# Figure 2: Ranked sector trends
# ============================================================

display = var.dropna(subset=['trend_Gt_yr_dec']).sort_values('trend_Gt_yr_dec')

fig2, ax = plt.subplots(figsize=(7, max(5, len(display) * 0.35)))
adj(ax, ['left', 'bottom'])

y = np.arange(len(display))
bar_colors = [SECTOR_COLORS[s] for s in display.index]
bars = ax.barh(y, display['trend_Gt_yr_dec'], color=bar_colors, alpha=0.9, edgecolor='none')

for bar, (_, row) in zip(bars, display.iterrows()):
    if row['trend_Gt_yr_dec'] < 0:
        bar.set_hatch('///')
        bar.set_alpha(0.65)

for i, (_, row) in enumerate(display.iterrows()):
    stars = sig_stars(row['trend_p'])
    if stars != 'n.s.':
        xpos = row['trend_Gt_yr_dec'] + (0.05 if row['trend_Gt_yr_dec'] >= 0 else -0.05)
        ha = 'left' if row['trend_Gt_yr_dec'] >= 0 else 'right'
        ax.text(xpos, i, stars, va='center', ha=ha, fontsize=7, color='k')

ax.axvline(0, color='k', linewidth=0.8)
ax.set_yticks(y)
ax.set_yticklabels(display.index, fontsize=8)
ax.set_xlabel('Trend [Gt yr$^{-1}$ dec$^{-1}$]')
ax.set_title('Sector discharge trends', fontsize=9, loc='left')

from matplotlib.patches import Patch
handles = [Patch(color=c, label=GROUP_NAMES[g]) for g, c in GROUP_COLORS.items()]
ax.legend(handles=handles, fontsize=7, frameon=False, loc='lower right', ncol=2, handlelength=1)

fig2.tight_layout()
fig2.savefig('./figs/sector_variability_ranked_trends.png', dpi=300, bbox_inches='tight')
plt.close(fig2)

# ============================================================
# Figure 3: Per-sector time series with annual trend
# ============================================================

n = len(SECTORS)
ncols = 3
nrows = int(np.ceil(n / ncols))

fig3, axes = plt.subplots(nrows, ncols, figsize=(4 * ncols, 2.6 * nrows), sharex=True)
axes = axes.flatten()

for ax, sector in zip(axes, SECTORS):
    adj(ax, ['left', 'bottom'])
    color = SECTOR_COLORS[sector]

    ax.plot(D.index, D[sector], color=color, linewidth=1.0, zorder=3)
    ax.fill_between(D.index, D[sector] - err[sector], D[sector] + err[sector],
                     color=color, alpha=0.2, zorder=1)

    ann = annual_means(D[sector].dropna())
    if len(ann) >= 5:
        years = np.array(ann.index, dtype=float)
        slope, intercept, p = lintrend(years, ann.values)
        x_dt = pd.to_datetime([f"{int(y)}-07-01" for y in years])
        ax.plot(x_dt, slope * years + intercept, 'k--', linewidth=1.2, zorder=4)
        row = var.loc[sector]
        ax.text(0.03, 0.95,
                f"{row['trend_Gt_yr_dec']:+.2f} Gt yr$^{{-1}}$ dec$^{{-1}}$ ({sig_stars(row['trend_p'])})",
                transform=ax.transAxes, ha='left', va='top', fontsize=6.5,
                bbox=dict(facecolor='white', alpha=0.7, edgecolor='none', pad=1))

    region = GROUP_NAMES[sector.split('.')[0]]
    ax.set_title(f'Sector {sector} ({region})', fontsize=9, loc='left')
    ax.set_ylabel('D [Gt yr$^{-1}$]', fontsize=7.5)

for ax in axes[n:]:
    ax.axis('off')

for ax in axes[max(0, n - ncols):n]:
    ax.set_xlabel('Date')
    ax.xaxis.set_major_locator(mdates.YearLocator(2))

fig3.tight_layout()
fig3.subplots_adjust(hspace=0.45, wspace=0.35)
fig3.savefig('./figs/sector_variability_trend.png', dpi=300, bbox_inches='tight')
plt.close(fig3)

print("Saved:")
print("  figs/sector_variability_scatter.png")
print("  figs/sector_variability_ranked_trends.png")
print("  figs/sector_variability_trend.png")
