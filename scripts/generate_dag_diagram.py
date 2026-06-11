"""
Generate the Airflow pipeline DAG flow diagram for the Amar Bank workshop.
Output: ../diagrams/airflow_pipeline_flow.png

Run: python3 scripts/generate_dag_diagram.py
"""
import os
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "diagrams"))
os.makedirs(OUT, exist_ok=True)

# Snowflake-ish palette
C_BG = "#FFFFFF"
C_AIRFLOW = "#017CEE"
C_SF = "#29B5E8"
C_S3 = "#E8A33D"
C_TASK = "#EAF6FD"
C_TASK_EDGE = "#29B5E8"
C_TEXT = "#1B2A4A"
C_LANE = "#F4F8FB"

fig, ax = plt.subplots(figsize=(15, 8.2), dpi=160)
ax.set_xlim(0, 15)
ax.set_ylim(0, 8.2)
ax.axis("off")
fig.patch.set_facecolor(C_BG)


def box(x, y, w, h, text, fc, ec, tc="white", fs=11, bold=True, radius=0.12):
    p = FancyBboxPatch((x, y), w, h, boxstyle=f"round,pad=0.02,rounding_size={radius}",
                       linewidth=1.6, edgecolor=ec, facecolor=fc, zorder=3)
    ax.add_patch(p)
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center",
            color=tc, fontsize=fs, fontweight="bold" if bold else "normal", zorder=4)


def arrow(x1, y1, x2, y2, color=C_TEXT, style="-|>", lw=2.0):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style,
                 mutation_scale=18, linewidth=lw, color=color, zorder=2))


# Title
ax.text(7.5, 7.85, "Amar Bank — Airflow Data Pipeline (DAG: amar_pipeline_end_to_end)",
        ha="center", va="center", fontsize=15, fontweight="bold", color=C_TEXT)
ax.text(7.5, 7.45, "Orkestrasi 100% di Airflow  •  Snowflake = compute + storage  •  dbt = transformasi",
        ha="center", va="center", fontsize=10, color="#5A6B85")

# Airflow lane (the orchestrator band)
lane = FancyBboxPatch((0.4, 4.0), 14.2, 2.5, boxstyle="round,pad=0.02,rounding_size=0.15",
                      linewidth=1.4, edgecolor=C_AIRFLOW, facecolor=C_LANE, zorder=1)
ax.add_patch(lane)
ax.text(0.75, 6.25, "AIRFLOW (laptop / Docker) — sang pengatur",
        ha="left", va="center", fontsize=11, fontweight="bold", color=C_AIRFLOW)

# Tasks inside the Airflow lane
ty, th = 4.45, 1.25
box(0.7, ty, 2.7, th, "ingest_bronze\n(5 × COPY INTO)", C_TASK, C_TASK_EDGE, tc=C_TEXT, fs=10)
box(3.95, ty, 3.0, th, "execute_dbt_project\n_snapshot\n(SCD-2)", C_TASK, C_TASK_EDGE, tc=C_TEXT, fs=9.5)
box(7.5, ty, 3.0, th, "execute_dbt_project\n_build\n(Silver + Gold)", C_TASK, C_TASK_EDGE, tc=C_TEXT, fs=9.5)
box(11.05, ty, 2.9, th, "dq_gate\n(SP_DQ_GATE)", C_TASK, C_TASK_EDGE, tc=C_TEXT, fs=10)

# task-to-task arrows
arrow(3.4, ty + th / 2, 3.95, ty + th / 2, color=C_AIRFLOW)
arrow(6.95, ty + th / 2, 7.5, ty + th / 2, color=C_AIRFLOW)
arrow(10.5, ty + th / 2, 11.05, ty + th / 2, color=C_AIRFLOW)

# S3 source (left, below)
box(0.7, 1.0, 2.6, 1.2, "AWS S3\n(public bucket)\ncustomers / loans /\nrepayments / savings /\ntransactions .csv",
    C_S3, "#C77F1A", tc="white", fs=8.5)

# Snowflake medallion (right, below)
box(4.4, 1.0, 2.2, 1.2, "BRONZE\nRAW_* tables", C_SF, "#1C84A8", tc="white", fs=10)
box(7.0, 1.0, 2.2, 1.2, "SILVER\nSTG_* + SCD-2", C_SF, "#1C84A8", tc="white", fs=10)
box(9.6, 1.0, 2.2, 1.2, "GOLD\nMART_*", C_SF, "#1C84A8", tc="white", fs=10)
ax.text(8.1, 2.55, "SNOWFLAKE (cloud) — tempat data & semua pengolahan terjadi",
        ha="center", va="center", fontsize=10.5, fontweight="bold", color="#1C84A8")

# medallion arrows
arrow(6.6, 1.6, 7.0, 1.6, color="#1C84A8")
arrow(9.2, 1.6, 9.6, 1.6, color="#1C84A8")

# vertical "commands" arrows from Airflow tasks down to Snowflake/S3
arrow(2.05, ty, 2.0, 2.2, color="#9AA7BD", style="-|>", lw=1.6)   # ingest -> S3/Bronze
ax.text(2.35, 3.35, "COPY INTO", ha="left", va="center", fontsize=8, color="#5A6B85", rotation=90)
arrow(2.05, 2.2, 4.4, 1.85, color="#9AA7BD", style="-|>", lw=1.4)  # S3/bronze fill

arrow(9.0, ty, 8.1, 2.2, color="#9AA7BD", style="-|>", lw=1.6)    # dbt build -> Silver/Gold
ax.text(8.7, 3.35, "EXECUTE DBT PROJECT", ha="left", va="center", fontsize=8, color="#5A6B85", rotation=90)

arrow(12.5, ty, 10.7, 2.2, color="#9AA7BD", style="-|>", lw=1.6)  # dq_gate -> Gold
ax.text(12.0, 3.35, "CALL SP_DQ_GATE", ha="left", va="center", fontsize=8, color="#5A6B85", rotation=90)

# legend
ax.text(0.75, 0.45, "Alur: file S3  →  COPY INTO (Bronze)  →  EXECUTE DBT PROJECT (Silver → Gold)  →  Data Quality gate",
        ha="left", va="center", fontsize=9.5, color=C_TEXT, style="italic")

plt.tight_layout()
out_path = os.path.join(OUT, "airflow_pipeline_flow.png")
plt.savefig(out_path, dpi=160, bbox_inches="tight", facecolor=C_BG)
print("Saved:", out_path)
