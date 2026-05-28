"""
Compare phase3_dev (monthly dSEC) against main (annual SEC) discharge results.
Reads from ./out/ (dev) and ../MFID-main/out/ (main).
Saves figs/compare_branches.png and figs/compare_branches_sectors.png.
"""
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import os

os.makedirs("./figs", exist_ok=True)

MAIN = "../MFID-main/out"
DEV  = "./out"

C_DEV  = "#e31a1c"   # red
C_MAIN = "#1f78b4"   # blue
LW = 1.2

def load(path, f):
    return pd.read_csv(f"{path}/{f}", index_col=0, parse_dates=True)

gis_dev  = load(DEV,  "GIS_D.csv")
gis_main = load(MAIN, "GIS_D.csv")
err_dev  = load(DEV,  "GIS_err.csv")
err_main = load(MAIN, "GIS_err.csv")
reg_dev  = load(DEV,  "region_D.csv")
reg_main = load(MAIN, "region_D.csv")
sec_dev  = load(DEV,  "sector_D.csv")
sec_main = load(MAIN, "sector_D.csv")

common = gis_dev.index.intersection(gis_main.index)

REGIONS = ["CE", "CW", "NE", "NO", "NW", "SE", "SW"]
REGION_NAMES = {
    "CE": "Central East", "CW": "Central West",
    "NE": "North East",   "NO": "North",
    "NW": "North West",   "SE": "South East", "SW": "South West",
}
SECTORS = sorted(sec_dev.columns.tolist())

# ── Figure 1: GIS + 7 regions ─────────────────────────────────────────────────
fig = plt.figure(figsize=(14, 16))
gs0 = gridspec.GridSpec(4, 2, figure=fig, hspace=0.45, wspace=0.3,
                        height_ratios=[1.4, 1, 1, 1])

def plot_ts(ax, idx, dev, main, err_d, err_m, title):
    ax.fill_between(idx,
        (dev.loc[idx].values - err_d.loc[idx].values).flatten(),
        (dev.loc[idx].values + err_d.loc[idx].values).flatten(),
        color=C_DEV, alpha=0.15)
    ax.fill_between(idx,
        (main.loc[idx].values - err_m.loc[idx].values).flatten(),
        (main.loc[idx].values + err_m.loc[idx].values).flatten(),
        color=C_MAIN, alpha=0.15)
    ax.plot(idx, dev.loc[idx].values,  color=C_DEV,  lw=LW, label="dev (monthly dSEC)")
    ax.plot(idx, main.loc[idx].values, color=C_MAIN, lw=LW, label="main (annual SEC)", linestyle="--")
    ax.set_title(title, fontsize=9)
    ax.set_ylabel("Gt yr⁻¹", fontsize=8)
    ax.tick_params(labelsize=7)

# GIS panel spans full top row
ax_gis = fig.add_subplot(gs0[0, :])
reg_err_dev  = load(DEV,  "region_D.csv") * 0  # placeholder — use GIS err scaled
# Use actual err files if they exist; otherwise skip shading for regions
try:
    reg_err_dev  = load(DEV,  "region_err.csv")
    reg_err_main = load(MAIN, "region_err.csv")
    has_reg_err = True
except FileNotFoundError:
    has_reg_err = False

plot_ts(ax_gis, common,
        gis_dev.iloc[:, 0:1], gis_main.iloc[:, 0:1],
        err_dev.iloc[:, 0:1], err_main.iloc[:, 0:1],
        "Greenland Ice Sheet — total discharge")
ax_gis.legend(fontsize=8, loc="upper left")

# Region panels
positions = [(1,0),(1,1),(2,0),(2,1),(3,0),(3,1),(3,1)]
axes_reg = {}
for i, reg in enumerate(REGIONS):
    row, col = [(1,0),(1,1),(2,0),(2,1),(3,0),(3,1),(3,1)][i]
    if reg == "SW":  # last one: different position to avoid overlap
        row, col = 3, 1
    ax = fig.add_subplot(gs0[row, col]) if reg != "SW" else fig.add_subplot(gs0[3, 1])
    axes_reg[reg] = ax

# re-do cleanly
for ax in fig.axes[1:]:
    fig.delaxes(ax)

axes_reg = {}
reg_positions = [(1,0),(1,1),(2,0),(2,1),(3,0),(3,1),(3,1)]
used = set()
for i, reg in enumerate(REGIONS):
    r, c = [(1,0),(1,1),(2,0),(2,1),(3,0),(3,1),(2,1)][i]
    # place SW differently to avoid collision
    if i == 6:
        r, c = 3, 1
    axes_reg[reg] = fig.add_subplot(gs0[r, c])

for reg in REGIONS:
    ax = axes_reg[reg]
    d_d = reg_dev[[reg]]
    d_m = reg_main[[reg]]
    if has_reg_err:
        e_d = reg_err_dev[[reg]]
        e_m = reg_err_main[[reg]]
        ax.fill_between(common,
            (d_d.loc[common].values - e_d.loc[common].values).flatten(),
            (d_d.loc[common].values + e_d.loc[common].values).flatten(),
            color=C_DEV, alpha=0.15)
        ax.fill_between(common,
            (d_m.loc[common].values - e_m.loc[common].values).flatten(),
            (d_m.loc[common].values + e_m.loc[common].values).flatten(),
            color=C_MAIN, alpha=0.15)
    ax.plot(common, d_d.loc[common].values, color=C_DEV,  lw=LW)
    ax.plot(common, d_m.loc[common].values, color=C_MAIN, lw=LW, linestyle="--")
    mean_diff = (d_d.loc[common] - d_m.loc[common]).mean().iloc[0]
    ax.set_title(f"{REGION_NAMES[reg]}  (Δ̄={mean_diff:+.1f} Gt/yr)", fontsize=8)
    ax.set_ylabel("Gt yr⁻¹", fontsize=7)
    ax.tick_params(labelsize=7)

fig.suptitle("Discharge comparison: phase3_dev (monthly dSEC, red) vs main (annual SEC, blue dashed)",
             fontsize=10, y=0.98)
plt.savefig("./figs/compare_branches.png", dpi=150, bbox_inches="tight")
plt.close()
print("Saved figs/compare_branches.png")

# ── Figure 2: all sectors ─────────────────────────────────────────────────────
n = len(SECTORS)
ncols = 4
nrows = int(np.ceil(n / ncols))

try:
    sec_err_dev  = load(DEV,  "sector_err.csv")
    sec_err_main = load(MAIN, "sector_err.csv")
    has_sec_err = True
except FileNotFoundError:
    has_sec_err = False

fig2, axes = plt.subplots(nrows, ncols, figsize=(ncols * 3.5, nrows * 2.8),
                          sharex=True)
axes_flat = axes.flatten()

for i, sec in enumerate(SECTORS):
    ax = axes_flat[i]
    d_d = sec_dev[[sec]]
    d_m = sec_main[[sec]]
    if has_sec_err:
        ax.fill_between(common,
            (d_d.loc[common].values - sec_err_dev[[sec]].loc[common].values).flatten(),
            (d_d.loc[common].values + sec_err_dev[[sec]].loc[common].values).flatten(),
            color=C_DEV, alpha=0.15)
        ax.fill_between(common,
            (d_m.loc[common].values - sec_err_main[[sec]].loc[common].values).flatten(),
            (d_m.loc[common].values + sec_err_main[[sec]].loc[common].values).flatten(),
            color=C_MAIN, alpha=0.15)
    ax.plot(common, d_d.loc[common].values, color=C_DEV,  lw=LW)
    ax.plot(common, d_m.loc[common].values, color=C_MAIN, lw=LW, linestyle="--")
    mean_diff = (d_d.loc[common] - d_m.loc[common]).mean().iloc[0]
    ax.set_title(f"Sector {sec}  (Δ̄={mean_diff:+.1f})", fontsize=8)
    ax.set_ylabel("Gt yr⁻¹", fontsize=7)
    ax.tick_params(labelsize=7)

# Hide unused panels
for j in range(i + 1, len(axes_flat)):
    axes_flat[j].set_visible(False)

# Shared legend
from matplotlib.lines import Line2D
handles = [Line2D([0],[0], color=C_DEV,  lw=LW, label="dev (monthly dSEC)"),
           Line2D([0],[0], color=C_MAIN, lw=LW, linestyle="--", label="main (annual SEC)")]
fig2.legend(handles=handles, loc="lower right", fontsize=9, ncol=2,
            bbox_to_anchor=(0.98, 0.01))

fig2.suptitle("Sector discharge: phase3_dev vs main", fontsize=11, y=1.001)
plt.tight_layout()
plt.savefig("./figs/compare_branches_sectors.png", dpi=150, bbox_inches="tight")
plt.close()
print("Saved figs/compare_branches_sectors.png")
