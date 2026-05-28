"""
Gate-level discharge comparison: phase3_dev (monthly dSEC) vs main (annual SEC).

Two-panel figure:
  Left  – map of gate positions (EPSG:3413 projected), coloured by mean dev−main
  Right – circumferential plot: gates ordered clockwise from north, showing
          mean discharge (dev vs main) and the difference below
"""
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.colors as mcolors
import os

os.makedirs("./figs", exist_ok=True)

MAIN = "../MFID-main/out"
DEV  = "./out"
C_DEV  = "#e31a1c"
C_MAIN = "#1f78b4"

# ── Load data ─────────────────────────────────────────────────────────────────
meta = pd.read_csv(f"{DEV}/gate_meta.csv", index_col=0)

dev_D  = pd.read_csv(f"{DEV}/gate_D.csv",   index_col=0, parse_dates=True)
main_D = pd.read_csv(f"{MAIN}/gate_D.csv",  index_col=0, parse_dates=True)

# Gate IDs are strings in CSV columns, integers in meta index
dev_D.columns  = dev_D.columns.astype(int)
main_D.columns = main_D.columns.astype(int)

common_times = dev_D.index.intersection(main_D.index)
common_gates = meta.index[meta.index.isin(dev_D.columns) &
                           meta.index.isin(main_D.columns)]

mean_dev  = dev_D.loc[common_times, common_gates].mean()
mean_main = main_D.loc[common_times, common_gates].mean()
mean_diff = mean_dev - mean_main   # positive = dev > main

# ── Gate ordering: clockwise from north around Greenland ──────────────────────
cx = meta.loc[common_gates, "mean_x"].mean()
cy = meta.loc[common_gates, "mean_y"].mean()
dx = meta.loc[common_gates, "mean_x"] - cx
dy = meta.loc[common_gates, "mean_y"] - cy
# clockwise from north: atan2(east, north) mapped to [0, 2π]
angle = np.arctan2(dx, dy) % (2 * np.pi)
order = angle.sort_values().index   # gate IDs in clockwise order from north

mean_dev_ord  = mean_dev.loc[order]
mean_main_ord = mean_main.loc[order]
mean_diff_ord = mean_diff.loc[order]

# Region colours for map
REGION_COLORS = {"NO": "#a6cee3", "NE": "#1f78b4", "CE": "#b2df8a",
                 "SE": "#33a02c", "SW": "#fb9a99", "CW": "#e31a1c",
                 "NW": "#ff7f00"}

# Top-N gates by discharge for labelling
TOP_N = 12
top_gates = mean_dev.nlargest(TOP_N).index

# ── Figure ────────────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(18, 10))
gs0 = gridspec.GridSpec(1, 2, figure=fig, width_ratios=[1, 1.6], wspace=0.08)

# ── Left: map ─────────────────────────────────────────────────────────────────
ax_map = fig.add_subplot(gs0[0])

# Colour scale: diverging around 0 for diff
vmax = np.abs(mean_diff).quantile(0.95)
norm = mcolors.TwoSlopeNorm(vmin=-vmax, vcenter=0, vmax=vmax)
cmap = plt.cm.RdBu_r

sc = ax_map.scatter(
    meta.loc[common_gates, "mean_x"],
    meta.loc[common_gates, "mean_y"],
    c=mean_diff.values,
    cmap=cmap, norm=norm,
    s=40, zorder=3, edgecolors="k", linewidths=0.3
)
# Label top gates
for g in top_gates:
    ax_map.annotate(
        meta.loc[g, "Mouginot_2019"].replace("_", " ").title()[:18],
        (meta.loc[g, "mean_x"], meta.loc[g, "mean_y"]),
        fontsize=5, ha="center", va="bottom",
        xytext=(0, 5), textcoords="offset points", color="#222222"
    )

cb = fig.colorbar(sc, ax=ax_map, shrink=0.6, pad=0.02)
cb.set_label("Mean Δ discharge [Gt yr⁻¹]\n(dev − main)", fontsize=8)
cb.ax.tick_params(labelsize=7)

ax_map.set_aspect("equal")
ax_map.set_xlabel("x (m, EPSG:3413)", fontsize=8)
ax_map.set_ylabel("y (m, EPSG:3413)", fontsize=8)
ax_map.tick_params(labelsize=7)
ax_map.set_title("Gate positions — mean discharge difference", fontsize=9)

# ── Right: circumferential plot ───────────────────────────────────────────────
gs1 = gridspec.GridSpecFromSubplotSpec(3, 1, subplot_spec=gs0[1],
                                       hspace=0.08,
                                       height_ratios=[2, 2, 1])
ax_dev  = fig.add_subplot(gs1[0])
ax_main = fig.add_subplot(gs1[1], sharex=ax_dev)
ax_dif  = fig.add_subplot(gs1[2], sharex=ax_dev)

x = np.arange(len(order))

ax_dev.bar(x, mean_dev_ord.values,  color=C_DEV,  alpha=0.85, width=1.0)
ax_main.bar(x, mean_main_ord.values, color=C_MAIN, alpha=0.85, width=1.0)

diff_vals = mean_diff_ord.values
colors_diff = [C_DEV if v > 0 else C_MAIN for v in diff_vals]
ax_dif.bar(x, diff_vals, color=colors_diff, alpha=0.85, width=1.0)
ax_dif.axhline(0, color="k", linewidth=0.6)

# Label top gates on circumferential x-axis
tick_pos = [np.where(order == g)[0][0] for g in top_gates if g in order]
tick_labels = [meta.loc[g, "Mouginot_2019"].replace("_", " ").title()[:16]
               for g in top_gates if g in order]
ax_dif.set_xticks(tick_pos)
ax_dif.set_xticklabels(tick_labels, rotation=45, ha="right", fontsize=6)

# Add region boundaries as vertical lines
region_order = meta.loc[order, "region"]
for i in range(1, len(order)):
    if region_order.iloc[i] != region_order.iloc[i - 1]:
        for ax in [ax_dev, ax_main, ax_dif]:
            ax.axvline(i - 0.5, color="grey", linewidth=0.6, linestyle=":")
        mid = i - 1 + 0.5 - 2
        ax_dev.text(i - 0.5, ax_dev.get_ylim()[1] if ax_dev.get_ylim()[1] > 0 else 1,
                    region_order.iloc[i - 1], fontsize=7, color="grey",
                    ha="right", va="top")

ax_dev.set_ylabel("Gt yr⁻¹", fontsize=8)
ax_main.set_ylabel("Gt yr⁻¹", fontsize=8)
ax_dif.set_ylabel("Δ Gt yr⁻¹", fontsize=8)
ax_dev.tick_params(labelbottom=False, labelsize=7)
ax_main.tick_params(labelbottom=False, labelsize=7)
ax_dif.tick_params(labelsize=7)
ax_dev.set_xlim(-0.5, len(order) - 0.5)

ax_dev.set_title("dev (monthly dSEC)", fontsize=9, color=C_DEV)
ax_main.set_title("main (annual SEC)", fontsize=9, color=C_MAIN)
ax_dif.set_title("dev − main", fontsize=9)

fig.suptitle("Gate-level discharge: phase3_dev vs main  |  clockwise from north →",
             fontsize=10, y=1.01)

plt.savefig("./figs/compare_gates.png", dpi=150, bbox_inches="tight")
plt.close()
print("Saved figs/compare_gates.png")
