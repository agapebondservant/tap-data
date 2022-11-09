import streamlit as st
import logging
import time
import pandas as pd
import numpy as np
from streamlit_autorefresh import st_autorefresh
import subprocess
import os
import config
import sys
import requests
from sqlalchemy.engine import create_engine
import json

# Initializations
st.set_option('deprecation.showPyplotGlobalUse', False)
top1000query = "select * from /claims c limit 1000"
totalPrimaryCountQuery = "select count(*) from /claims c where c.region = 'east'"
totalSecondaryCountQuery = "select count(*) from /claims c where c.region = 'west'"

st.write("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Nanum Gothic');
html, body, [class*="css"]{
   font-family: 'Nanum Gothic';
}
#tanzu-realtime-anomaly-detection-demo{
   color: #6a6161;
}
.blinking {
  animation: blinker 1s linear infinite;
  background: url('https://github.com/agapebondservant/tanzu-realtime-anomaly-detetction/blob/main/app/assets/clock.png?raw=true') no-repeat right;
}
@keyframes blinker {
  50% {
    opacity: 0;
  }
}
.oracle {
  background: url('https://raw.githubusercontent.com/agapebondservant/tanzu-realtime-anomaly-detetction/main/assets/oracle.png') no-repeat right;
  background-size: 150px;
  width: 150px;
  height: 100px;
}
.mysql {
  background: url('https://raw.githubusercontent.com/agapebondservant/tanzu-realtime-anomaly-detetction/main/assets/mysql.png') no-repeat right;
  background-size: 150px;
  width: 150px;
  height: 100px;
}
.user-site {
  font-size: 1.6em;
}
span.secondary {
    color: red;
    font-weight: bold;
}
</style>
""", unsafe_allow_html=True)

st.header('Realtime Dashboard')

st.text('Showcases WAN Replication with VMware Gemfire')

# Tables
# base_key = time.time()

if 'msg_rate' not in st.session_state:
    st.session_state['msg_rate'] = 1000

tab1, tab2 = st.tabs(["Oracle", "MySQL"])


def show_counts():
    logging.info("Refreshing dashboard...")

    lb_url = os.environ[f"{sys.argv[1].upper()}_URL"]

    sticky_bit = eval(requests.get(f"http://{lb_url}:7070/gemfire-api/v1/sticky/bit").text) or 'PRIMARY_URL'

    gemfire_url = f"http://{os.environ[sticky_bit]}:7070/gemfire-api/v1"

    current_site = sticky_bit.lower().replace('_url', '') or sys.argv[1]

    print(f'Base URL: {lb_url} Gemfire URL: {gemfire_url} Sticky Bit: {sticky_bit} Current Site: {current_site}')

    st.markdown(
        f"<div class='user-site'>User Site: <font color=blue><span class='{current_site}'>{current_site}</span></font></div>",
        unsafe_allow_html=True)

    st.markdown("<div class='blinking'>&nbsp;</div>", unsafe_allow_html=True)

    # data = requests.get(f"{gemfire_url}/claims", params={"q": top1000query}).json()

    total_primary = requests.get(f"{gemfire_url}/queries/adhoc", params={"q": totalPrimaryCountQuery}).text

    total_secondary = requests.get(f"{gemfire_url}/queries/adhoc", params={"q": totalSecondaryCountQuery}).text

    logging.info(f"\nTotal Primary:\n{total_primary}\nTotal Secondary:\n{total_secondary}")

    col1, col2 = st.columns(2)

    col1.metric("Total Primary", total_primary)

    col2.metric("Total Secondary", total_secondary)

    # df = pd.json_normalize(data)

    # st.dataframe(df)


with tab1:

    st.markdown(
        f"<div class='oracle'>&nbsp;</div>",
        unsafe_allow_html=True)

    show_counts()

with tab2:
    st.markdown(
        f"<div class='mysql'>&nbsp;</div>",
        unsafe_allow_html=True)
    show_counts()

# Refresh the screen at a configured interval
st_autorefresh(interval=5 * 1000, key="refresher")
