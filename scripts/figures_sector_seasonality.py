import matplotlib.cm as cm
import matplotlib.colors as mcolors
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from adjust_spines import adjust_spines as adj

D       = pd.read_csv('./out/sector_D.csv', index_col=0, parse_dates=True)
annual  = pd.read_csv('./out/sector_seasonality_annual.csv')
summary = pd.read_csv('./out/sector_seasonality.csv', index_col=0)
summary.index = summary.index.astype(str)

GROUP_NAMES = {'1': 'NO', '2': 'NE', '3': 'CE', '4': 'SE',
               '5': 'S', '6': 'SW', '7': 'CW', '8': 'NW'}

SECTORS = list(D.columns)
GROUPS  = [s.split('.')[0] for s in SECTORS]
GROUP_IDS = sorted(set(GROUPS), key=int)
cmap = cm.get_cmap('tab10', len(GROUP_IDS))
GROUP_COLORS = {g: cmap(i) for i, g in enumerate(GROUP_IDS)}
SECTOR_COLORS = {s: GROUP_COLORS[g] for s, g in zip(SECTORS, GROUPS)}

def sig_stars(p):
    return '***' if p < 0.001 else ('**' if p < 0.01 else ('*' if p < 0.05 else 'n.s.'))

# ============================================================
# Figure 1: seasonal cycle by year, one panel per sector
# ============================================================

MONTH_LABELS = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec']

years_all = sorted(D.index.year.unique())
norm7 = mcolors.Normalize(vmin=min(years_all), vmax=max(years_all))
cmap7 = cm.get_cmap('plasma', len(years_all))

ncols = 3
nrows = int(np.ceil(len(SECTORS) / ncols))
fig1, axes = plt.subplots(nrows, ncols, figsize=(4 * ncols, 2.6 * nrows))
axes = axes.flatten()

for ax, sector in zip(axes, SECTORS):
    adj(ax, ['left', 'bottom'])
    ts = D[sector].dropna()
    ax.axhline(0, color='k', linewidth=0.5, alpha=0.4)
    for year in sorted(ts.index.year.unique()):
        yd = ts[ts.index.year == year]
        ax.plot(yd.index.month, yd.values - yd.mean(),
                color=cmap7(norm7(year)), linewidth=1.0, marker='o', markersize=2)
    ax.set_title(f'Sector {sector}', fontsize=9, loc='left')
    ax.set_ylabel('D anomaly\n[Gt yr$^{-1}$]', fontsize=7)
    ax.set_xlim(0.5, 12.5)
    ax.set_xticks(range(1, 13))
    ax.set_xticklabels([])
    if sector in summary.index:
        ax.text(0.97, 0.95, f"R$^2$={summary.loc[sector, 'r2_mean']:.2f}",
                transform=ax.transAxes, ha='right', va='top', fontsize=6.5, color='grey')

for ax in axes[len(SECTORS):]:
    ax.axis('off')

for ax in axes[max(0, len(SECTORS) - ncols):len(SECTORS)]:
    ax.set_xticklabels(MONTH_LABELS, fontsize=6.5)
    ax.set_xlabel('Month')

fig1.subplots_adjust(hspace=0.55, wspace=0.5)

sm = cm.ScalarMappable(cmap=cmap7, norm=norm7)
sm.set_array([])
cbar = fig1.colorbar(sm, ax=axes, shrink=0.5, pad=0.02, aspect=40)
cbar.set_label('Year', fontsize=8)
cbar.set_ticks(years_all)
cbar.ax.yaxis.set_tick_params(labelsize=6.5)

fig1.savefig('./figs/sector_seasonality_cycle.png', dpi=300, bbox_inches='tight')
plt.close(fig1)

# ============================================================
# Figure 2: ranked amplitude trend
# ============================================================

def ranked_bar(column, p_column, xlabel, title, fname):
    display = summary.dropna(subset=[column]).sort_values(column)

    fig, ax = plt.subplots(figsize=(7, max(5, len(display) * 0.35)))
    adj(ax, ['left', 'bottom'])

    y = np.arange(len(display))
    bar_colors = [SECTOR_COLORS[s] for s in display.index]
    bars = ax.barh(y, display[column], color=bar_colors, alpha=0.9, edgecolor='none')

    for bar, (_, row) in zip(bars, display.iterrows()):
        if row[column] < 0:
            bar.set_hatch('///')
            bar.set_alpha(0.65)

    for i, (_, row) in enumerate(display.iterrows()):
        stars = sig_stars(row[p_column])
        if stars != 'n.s.':
            xpos = row[column] + (0.02 * display[column].abs().max() if row[column] >= 0
                                   else -0.02 * display[column].abs().max())
            ha = 'left' if row[column] >= 0 else 'right'
            ax.text(xpos, i, stars, va='center', ha=ha, fontsize=7, color='k')

    ax.axvline(0, color='k', linewidth=0.8)
    ax.set_yticks(y)
    ax.set_yticklabels(display.index, fontsize=8)
    ax.set_xlabel(xlabel)
    ax.set_title(title, fontsize=9, loc='left')

    from matplotlib.patches import Patch
    handles = [Patch(color=c, label=GROUP_NAMES[g]) for g, c in GROUP_COLORS.items()]
    ax.legend(handles=handles, fontsize=7, frameon=False, loc='lower right', ncol=2, handlelength=1)

    fig.tight_layout()
    fig.savefig(f'./figs/{fname}', dpi=300, bbox_inches='tight')
    plt.close(fig)

ranked_bar('amplitude_trend_Gt_yr_dec', 'amplitude_trend_p',
           'Amplitude trend [Gt yr$^{-1}$ dec$^{-1}$]',
           'Sector seasonal-amplitude trend (annual-harmonic fit)',
           'sector_seasonality_amplitude_trend.png')

# ============================================================
# Figure 3: ranked phase-shift trend
# ============================================================

ranked_bar('phase_trend_days_dec', 'phase_trend_p',
           'Peak-timing shift [days dec$^{-1}$] (+ = later in year)',
           'Sector peak-timing shift (annual-harmonic fit)',
           'sector_seasonality_phase_trend.png')

print("Saved:")
print("  figs/sector_seasonality_cycle.png")
print("  figs/sector_seasonality_amplitude_trend.png")
print("  figs/sector_seasonality_phase_trend.png")
