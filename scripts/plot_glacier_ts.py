"""
Time series comparison of gate discharge: phase3_dev (monthly dSEC) vs main (annual SEC).

Generates two figures:
  figs/glacier_ts_ne.png   — NE Greenland: Nioghalvfjerdsfjorden, Zachariae, Humboldt
  figs/glacier_ts_large.png — Major outlets: Jakobshavn, Kangerlussuaq, Helheim
"""
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import os

os.makedirs("./figs", exist_ok=True)

MAIN = "../MFID-main/out"
DEV  = "./out"
C_DEV  = "#e31a1c"
C_MAIN = "#1f78b4"

# Gates to plot; list of gate IDs is summed to give glacier total
FIGURES = {
    "figs/glacier_ts_ne.png": {
        "title": "NE Greenland outlet glaciers — dev vs main",
        "glaciers": [
            ([15],      "Nioghalvfjerdsfjorden (79N)"),
            ([16],      "Zachariae Isstrøm"),
            ([14],      "Humboldt Gletscher"),
        ],
    },
    "figs/glacier_ts_large.png": {
        "title": "Major outlet glaciers — dev vs main",
        "glaciers": [
            ([181],     "Jakobshavn Isbræ (Sermeq Kujalleq)"),
            ([185],     "Kangerlussuaq Gletsjer"),
            ([236,238], "Helheim Gletsjer"),
        ],
    },
}


def load(path, f):
    df = pd.read_csv(f"{path}/{f}", index_col=0, parse_dates=True)
    df.columns = df.columns.astype(int)
    return df


dev_D    = load(DEV,  "gate_D.csv")
main_D   = load(MAIN, "gate_D.csv")
dev_err  = load(DEV,  "gate_err.csv")
main_err = load(MAIN, "gate_err.csv")

common = dev_D.index.intersection(main_D.index)


def glacier_ts(df, gates):
    """Sum discharge (or error in quadrature) across gates."""
    cols = [g for g in gates if g in df.columns]
    return df.loc[common, cols].sum(axis=1)


def glacier_err(df, gates):
    """Combine errors in quadrature across gates."""
    cols = [g for g in gates if g in df.columns]
    return np.sqrt((df.loc[common, cols] ** 2).sum(axis=1))


for outfile, cfg in FIGURES.items():
    n = len(cfg["glaciers"])
    fig, axes = plt.subplots(n, 1, figsize=(11, 3.2 * n), sharex=True)
    if n == 1:
        axes = [axes]
    fig.subplots_adjust(hspace=0.38)

    for ax, (gates, name) in zip(axes, cfg["glaciers"]):
        d_dev   = glacier_ts(dev_D,   gates)
        d_main  = glacier_ts(main_D,  gates)
        e_dev   = glacier_err(dev_err,  gates)
        e_main  = glacier_err(main_err, gates)

        ax.fill_between(common, d_dev - e_dev,   d_dev + e_dev,
                        color=C_DEV,  alpha=0.15)
        ax.fill_between(common, d_main - e_main,  d_main + e_main,
                        color=C_MAIN, alpha=0.15)
        ax.plot(common, d_dev,  color=C_DEV,  lw=1.5, label="dev (monthly dSEC)")
        ax.plot(common, d_main, color=C_MAIN, lw=1.5, linestyle="--",
                label="main (annual SEC)")

        ax.axhline(d_dev.mean(),  color=C_DEV,  lw=0.6, linestyle=":")
        ax.axhline(d_main.mean(), color=C_MAIN, lw=0.6, linestyle=":")

        mean_diff = (d_dev - d_main).mean()
        gate_str = "+".join(str(g) for g in gates)
        ax.text(0.02, 0.97,
                f"gate(s) {gate_str}  |  "
                f"mean dev={d_dev.mean():.2f}  main={d_main.mean():.2f}  "
                f"Δ={mean_diff:+.2f} Gt yr⁻¹",
                transform=ax.transAxes, fontsize=8, va="top",
                bbox=dict(fc="white", ec="none", alpha=0.7))

        ax.set_ylabel("Discharge [Gt yr⁻¹]", fontsize=9)
        ax.set_title(name, fontsize=10)
        ax.legend(fontsize=8, loc="upper right")
        ax.tick_params(labelsize=8)
        ax.xaxis.set_major_locator(mdates.YearLocator())
        ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))

    fig.suptitle(cfg["title"], fontsize=11)
    plt.savefig(outfile, dpi=150, bbox_inches="tight")
    plt.close()
    print(f"Saved {outfile}")
