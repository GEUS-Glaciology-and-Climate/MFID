"""
Compare monthly integrated DEMs (from dSEC) against annual PRODEMs at gate pixels.

Outputs saved to figs/:
  dem_vs_prodem_bias.png      - mean bias per year, forward/backward from 2020 anchor
  dem_vs_prodem_scatter.png   - scatter: integrated DEM vs PRODEM for each year
  dem_vs_prodem_coverage.png  - fraction of gate pixels with non-constant DEM over time
"""
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os

os.makedirs("./figs", exist_ok=True)

# ── Load data ─────────────────────────────────────────────────────────────────

# Monthly integrated DEMs at gate pixels: rows=pixels, cols=monthly timestamps
dem_ts = pd.read_csv("./tmp/dem_ts.csv", index_col=0)
dem_ts.columns = pd.to_datetime(dem_ts.columns)

# PRODEM annual values at gate pixels: rows=pixels, cols=(x,y,gate,2019..2024)
prodem = pd.read_csv("./tmp/prodem_at_gates.csv")
prodem = prodem.replace("", np.nan)
for col in ["2019","2020","2021","2022","2023","2024"]:
    prodem[col] = pd.to_numeric(prodem[col], errors="coerce")

# Gate pixel index in prodem matches row order of dem_ts
# (both derived from same gates_gateID export, same order)
prodem_years = [2019, 2020, 2021, 2022, 2023, 2024]

# ── 1. dSEC coverage: how many pixels have non-constant DEM? ──────────────────

varying = (dem_ts.std(axis=1) > 0.01).sum()
total = len(dem_ts)
print(f"Gate pixels with varying DEM (dSEC coverage): {varying}/{total} ({100*varying/total:.1f}%)")
print(f"Gate pixels with constant DEM (no dSEC data): {total-varying}/{total}")

# ── 2. For each PRODEM year, find best-matching month in integrated DEM ───────

# Anchor is July 2020; PRODEMs are assumed to represent approximately that season.
# Test July and adjacent months to find which minimises mean absolute error.
test_months = [5, 6, 7, 8, 9]  # May through September

print("\nMean absolute error (m) by month vs PRODEM year:")
print(f"{'month':>6}", end="")
for y in prodem_years:
    print(f"  {y}", end="")
print()

mae_by_month = {}
for m in test_months:
    row = []
    for y in prodem_years:
        # find the column closest to YYYY-MM-01
        target = pd.Timestamp(f"{y}-{m:02d}-01")
        if target not in dem_ts.columns:
            closest = dem_ts.columns[np.argmin(abs(dem_ts.columns - target))]
        else:
            closest = target
        integrated = dem_ts[closest].values
        ref = prodem[str(y)].values
        mask = np.isfinite(ref) & np.isfinite(integrated)
        mae = np.abs(integrated[mask] - ref[mask]).mean()
        row.append(mae)
    mae_by_month[m] = row
    print(f"  m={m:02d}", end="")
    for v in row:
        print(f"  {v:5.2f}", end="")
    print()

# Best month overall (lowest mean MAE across years)
best_month = min(test_months, key=lambda m: np.mean(mae_by_month[m]))
print(f"\nBest matching month: {best_month} (July=7 is the anchor)")

# ── 3. Bias time series (integrated − PRODEM) at best month ──────────────────

biases = {}
rmses = {}
n_valid = {}
for y in prodem_years:
    target = pd.Timestamp(f"{y}-{best_month:02d}-01")
    if target not in dem_ts.columns:
        target = dem_ts.columns[np.argmin(abs(dem_ts.columns - target))]
    integrated = dem_ts[target].values
    ref = prodem[str(y)].values
    mask = np.isfinite(ref) & np.isfinite(integrated)
    diff = integrated[mask] - ref[mask]
    biases[y] = diff.mean()
    rmses[y] = np.sqrt((diff**2).mean())
    n_valid[y] = mask.sum()
    print(f"{y}: bias={biases[y]:+.2f} m, RMSE={rmses[y]:.2f} m, n={n_valid[y]}")

# ── 4. Plots ──────────────────────────────────────────────────────────────────

years = list(biases.keys())
bias_vals = [biases[y] for y in years]
rmse_vals = [rmses[y] for y in years]

# -- Bias plot
fig, ax = plt.subplots(figsize=(8, 4))
ax.bar(years, bias_vals, color=["#e31a1c" if y > 2020 else "#1f78b4" if y < 2020 else "#33a02c"
                                 for y in years], alpha=0.8)
ax.errorbar(years, bias_vals, yerr=rmse_vals, fmt="none", color="k", capsize=4, linewidth=1.5)
ax.axhline(0, color="k", linewidth=0.8, linestyle="--")
ax.axvline(2020, color="#33a02c", linewidth=1, linestyle=":", label="Anchor year (2020)")
ax.set_xlabel("Year")
ax.set_ylabel("Integrated DEM − PRODEM (m)")
ax.set_title(f"Mean bias at gate pixels (month={best_month}, n≈{int(np.mean(list(n_valid.values())))} pixels)\n"
             f"Blue=backward integration, Red=forward, Green=anchor")
ax.legend(fontsize=8)
plt.tight_layout()
plt.savefig("./figs/dem_vs_prodem_bias.png", dpi=150)
plt.close()

# -- Scatter plots (one per year)
fig, axes = plt.subplots(2, 3, figsize=(12, 8))
for ax, y in zip(axes.flat, prodem_years):
    target = pd.Timestamp(f"{y}-{best_month:02d}-01")
    if target not in dem_ts.columns:
        target = dem_ts.columns[np.argmin(abs(dem_ts.columns - target))]
    integrated = dem_ts[target].values
    ref = prodem[str(y)].values
    mask = np.isfinite(ref) & np.isfinite(integrated)
    ax.scatter(ref[mask], integrated[mask], s=1, alpha=0.3, color="#1f78b4")
    lo = min(ref[mask].min(), integrated[mask].min())
    hi = max(ref[mask].max(), integrated[mask].max())
    ax.plot([lo, hi], [lo, hi], "k--", linewidth=0.8)
    ax.set_title(f"{y}  bias={biases[y]:+.1f} m  RMSE={rmses[y]:.1f} m")
    ax.set_xlabel("PRODEM (m)")
    ax.set_ylabel("Integrated DEM (m)")
fig.suptitle("Integrated DEM vs PRODEM at gate pixels", fontsize=12)
plt.tight_layout()
plt.savefig("./figs/dem_vs_prodem_scatter.png", dpi=150)
plt.close()

# -- dSEC coverage: histogram of std dev across time per pixel
fig, ax = plt.subplots(figsize=(7, 4))
stds = dem_ts.std(axis=1)
ax.hist(stds[stds > 0], bins=50, color="#1f78b4", alpha=0.8, edgecolor="none")
ax.set_xlabel("Std dev of integrated DEM over time (m)")
ax.set_ylabel("Number of gate pixels")
ax.set_title(f"dSEC temporal variability at gate pixels\n"
             f"{varying}/{total} pixels have varying DEM ({100*varying/total:.0f}%)")
ax.axvline(stds[stds > 0].median(), color="r", linestyle="--",
           label=f"Median = {stds[stds>0].median():.1f} m")
ax.legend()
plt.tight_layout()
plt.savefig("./figs/dem_vs_prodem_coverage.png", dpi=150)
plt.close()

# ── 5. dSEC vs PRODEM-difference comparison ───────────────────────────────────
# For each non-anchor year, compare:
#   accumulated dSEC  = dem_ts[year-MM] - dem_ts[2020-07]   (what dSEC says changed)
#   PRODEM difference = PRODEM(year)    - PRODEM(2020)       (what was actually measured)
# Using July (anchor month) for the integrated DEM to keep the baseline consistent.

anchor_col = pd.Timestamp("2020-07-01")
if anchor_col not in dem_ts.columns:
    anchor_col = dem_ts.columns[np.argmin(abs(dem_ts.columns - anchor_col))]
anchor_dem = dem_ts[anchor_col].values
anchor_prodem = prodem["2020"].values

compare_years = [y for y in prodem_years if y != 2020]

print("\ndSEC accumulated change vs PRODEM difference (relative to July 2020):")
print(f"{'year':>6}  {'bias(m)':>8}  {'RMSE(m)':>8}  {'n':>6}")

dsec_biases, dsec_rmses = {}, {}
for y in compare_years:
    target = pd.Timestamp(f"{y}-07-01")
    if target not in dem_ts.columns:
        target = dem_ts.columns[np.argmin(abs(dem_ts.columns - target))]
    dsec_change = dem_ts[target].values - anchor_dem          # accumulated dSEC
    prodem_change = prodem[str(y)].values - anchor_prodem     # measured change
    mask = np.isfinite(dsec_change) & np.isfinite(prodem_change)
    diff = dsec_change[mask] - prodem_change[mask]
    dsec_biases[y] = diff.mean()
    dsec_rmses[y] = np.sqrt((diff**2).mean())
    print(f"  {y}  {dsec_biases[y]:+8.2f}  {dsec_rmses[y]:8.2f}  {mask.sum():6d}")

# -- Plot: accumulated dSEC change vs PRODEM-measured change
fig, axes = plt.subplots(1, len(compare_years), figsize=(3.5 * len(compare_years), 4))
for ax, y in zip(axes, compare_years):
    target = pd.Timestamp(f"{y}-07-01")
    if target not in dem_ts.columns:
        target = dem_ts.columns[np.argmin(abs(dem_ts.columns - target))]
    dsec_change = dem_ts[target].values - anchor_dem
    prodem_change = prodem[str(y)].values - anchor_prodem
    mask = np.isfinite(dsec_change) & np.isfinite(prodem_change)
    ax.scatter(prodem_change[mask], dsec_change[mask], s=1, alpha=0.3,
               color="#e31a1c" if y > 2020 else "#1f78b4")
    lo = min(prodem_change[mask].min(), dsec_change[mask].min())
    hi = max(prodem_change[mask].max(), dsec_change[mask].max())
    ax.plot([lo, hi], [lo, hi], "k--", linewidth=0.8)
    ax.set_title(f"{y}\nbias={dsec_biases[y]:+.1f} m  RMSE={dsec_rmses[y]:.1f} m")
    ax.set_xlabel("PRODEM change from 2020 (m)")
    ax.set_ylabel("Accumulated dSEC from July 2020 (m)")
fig.suptitle("Accumulated dSEC vs measured PRODEM change (relative to July 2020)", fontsize=11)
plt.tight_layout()
plt.savefig("./figs/dsec_vs_prodem_change.png", dpi=150)
plt.close()

print("\nFigures saved to figs/")
