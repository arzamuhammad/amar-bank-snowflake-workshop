"""
Streamlit-in-Snowflake dashboard — Amar Bank Workshop (Session 2).
Reads GOLD marts (built by dbt). Deploy via Snowsight (Streamlit) or:
  snow streamlit deploy --database AMAR_WORKSHOP --schema GOLD
"""
import streamlit as st
import pandas as pd
import altair as alt
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Amar Bank — Portfolio Dashboard", layout="wide")
session = get_active_session()

st.title("Amar Bank — Loan Portfolio Dashboard")
st.caption("Synthetic data · GOLD marts built by dbt on Snowflake")


@st.cache_data(ttl=600)
def q(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


loans = q("SELECT * FROM AMAR_WORKSHOP.GOLD.MART_LOAN_PERFORMANCE")
cust = q("SELECT * FROM AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360")

# ---- KPIs ----
c1, c2, c3, c4 = st.columns(4)
c1.metric("Total Loans", f"{len(loans):,}")
npl = 100 * loans["IS_DEFAULT"].mean() if len(loans) else 0
c2.metric("NPL Rate", f"{npl:.1f}%")
c3.metric("Outstanding", f"Rp {loans['OUTSTANDING'].sum()/1e9:,.1f} B")
c4.metric("Customers", f"{len(cust):,}")

tab1, tab2, tab3 = st.tabs(["Portfolio", "Risk / DPD", "Customer 360"])

with tab1:
    by_seg = loans.groupby("PRODUCT_SEGMENT").agg(
        loans=("LOAN_ID", "count"),
        outstanding=("OUTSTANDING", "sum"),
        npl=("IS_DEFAULT", "mean"),
    ).reset_index()
    by_seg["npl_pct"] = (by_seg["npl"] * 100).round(2)
    st.subheader("Portfolio by product segment")
    st.altair_chart(
        alt.Chart(by_seg).mark_bar().encode(
            x="PRODUCT_SEGMENT", y="outstanding", color="PRODUCT_SEGMENT",
            tooltip=["PRODUCT_SEGMENT", "loans", "outstanding", "npl_pct"],
        ).properties(height=350),
        use_container_width=True,
    )
    st.dataframe(by_seg, use_container_width=True)

with tab2:
    dpd = loans.groupby("DPD_BUCKET").agg(
        loans=("LOAN_ID", "count"), outstanding=("OUTSTANDING", "sum")
    ).reset_index()
    st.subheader("Days Past Due (DPD) distribution")
    st.altair_chart(
        alt.Chart(dpd).mark_arc(innerRadius=60).encode(
            theta="loans", color="DPD_BUCKET", tooltip=["DPD_BUCKET", "loans", "outstanding"]
        ).properties(height=350),
        use_container_width=True,
    )

with tab3:
    prov = cust.groupby("PROVINCE").agg(
        customers=("CUSTOMER_ID", "count"),
        savings=("TOTAL_SAVINGS_BALANCE", "sum"),
        avg_score=("CREDIT_SCORE", "mean"),
    ).reset_index().sort_values("customers", ascending=False)
    st.subheader("Customers & savings by province")
    st.altair_chart(
        alt.Chart(prov).mark_bar().encode(
            x=alt.X("PROVINCE", sort="-y"), y="customers",
            tooltip=["PROVINCE", "customers", "savings", "avg_score"],
        ).properties(height=350),
        use_container_width=True,
    )
    st.dataframe(prov, use_container_width=True)
