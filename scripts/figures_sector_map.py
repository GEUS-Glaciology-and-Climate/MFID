import geopandas as gpd
import matplotlib.colors as mcolors
import matplotlib.pyplot as plt
import pandas as pd

SECTORS_SHP = './plot_data/Zwally_2012/sectors/sectors.shp'
COAST_SHP   = './plot_data/outlines/Kyst.shp'

sectors = gpd.read_file(SECTORS_SHP)
# cat encodes the sector ID directly: tens digit = main sector, ones digit = sub-sector
# (e.g. cat 32 -> "3.2", cat 50 -> "5.0"); see plot_data/Zwally_2012/README.org.
# Sector 1.4 has geometry but no gates/discharge, so it merges to NaN below.
sectors['sector'] = (sectors['cat'] // 10).astype(str) + '.' + (sectors['cat'] % 10).astype(str)
sectors = sectors.dissolve(by='sector').reset_index()

coast = gpd.read_file(COAST_SHP).to_crs(sectors.crs)

var = pd.read_csv('./out/sector_variability.csv', index_col=0)
var.index = var.index.astype(str)

gdf = sectors.merge(var, left_on='sector', right_index=True, how='left')

xmin, ymin, xmax, ymax = gdf.total_bounds
pad = 0.03 * max(xmax - xmin, ymax - ymin)

def draw_basemap(ax):
    coast.plot(ax=ax, color='#999999', linewidth=0.4, zorder=1)
    ax.set_xlim(xmin - pad, xmax + pad)
    ax.set_ylim(ymin - pad, ymax + pad)
    ax.set_aspect('equal')

def label_sectors(ax, gdf, **kwargs):
    for _, row in gdf.iterrows():
        c = row.geometry.representative_point()
        ax.annotate(row['sector'], (c.x, c.y), fontsize=7,
                    ha='center', va='center', **kwargs)

# ============================================================
# Map 1: discharge trend per sector
# ============================================================

fig, ax = plt.subplots(figsize=(7, 9))
draw_basemap(ax)

vmax = gdf['trend_Gt_yr_dec'].abs().max()
norm = mcolors.TwoSlopeNorm(vmin=-vmax, vcenter=0, vmax=vmax)

gdf.plot(column='trend_Gt_yr_dec', cmap='RdBu_r', norm=norm, ax=ax, zorder=2,
          edgecolor='k', linewidth=0.6,
          missing_kwds={'color': '#dddddd', 'edgecolor': 'k', 'label': 'No data'},
          legend=True, legend_kwds={'label': 'Trend [Gt yr$^{-1}$ dec$^{-1}$]', 'shrink': 0.6})

insig = gdf[gdf['trend_p'] >= 0.05]
if len(insig):
    insig.plot(ax=ax, facecolor='none', edgecolor='k', hatch='///', linewidth=0, zorder=3)

label_sectors(ax, gdf)
ax.set_axis_off()
ax.set_title('Sector discharge trend (hatched = not significant, p ≥ 0.05)', fontsize=10)
fig.tight_layout()
fig.savefig('./figs/sector_map_trend.png', dpi=300, bbox_inches='tight')
plt.close(fig)

# ============================================================
# Map 2: coefficient of variation per sector
# ============================================================

fig, ax = plt.subplots(figsize=(7, 9))
draw_basemap(ax)

gdf.plot(column='D_cv', cmap='viridis', ax=ax, zorder=2, edgecolor='k', linewidth=0.6,
          missing_kwds={'color': '#dddddd', 'edgecolor': 'k', 'label': 'No data'},
          legend=True, legend_kwds={'label': 'Coefficient of variation', 'shrink': 0.6})

label_sectors(ax, gdf, color='white')
ax.set_axis_off()
ax.set_title('Sector discharge variability', fontsize=10)
fig.tight_layout()
fig.savefig('./figs/sector_map_cv.png', dpi=300, bbox_inches='tight')
plt.close(fig)

print("Saved:")
print("  figs/sector_map_trend.png")
print("  figs/sector_map_cv.png")
