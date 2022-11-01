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

# Initializations
st.set_option('deprecation.showPyplotGlobalUse', False)
gemfire_url = f"http://{os.environ['STREAMLIT_ISTIO_INGRESS_HOST_' + sys.argv[1].upper()]}:7070/gemfire-api/v1/claims"
top10query = "select * from /claims c limit 10"
totalPrimaryCountQuery = "select count(*) from /claims c where c.region = 'primary'"
totalSecondaryCountQuery = "select count(*) from /claims c where c.region = 'secondary'"
print(getattr(config, sys.argv[1])[sys.argv[2]])
engine = create_engine(getattr(config, sys.argv[1])[sys.argv[2]])

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
}
.mysql {
  background: url('https://raw.githubusercontent.com/agapebondservant/tanzu-realtime-anomaly-detetction/main/assets/mysql.png') no-repeat right;
}
</style>
""", unsafe_allow_html=True)

st.header('Realtime Dashboard')

st.text('Showcases WAN Replication with VMware Gemfire')

st.markdown(f"<div class='{sys.argv[2]}'>&nbsp;</div><div>{sys.argv[2]}</div>", unsafe_allow_html=True)

# Tables
# base_key = time.time()

if 'msg_rate' not in st.session_state:
    st.session_state['msg_rate'] = 1000

logging.info("Refreshing dashboard...")

st.number_input('Message Rate', '''''', key='msg_rate', format='%i')

st.markdown("<div class='blinking'>&nbsp;</div>", unsafe_allow_html=True)

# subprocess.call(f"random_claim_generator {int(st.session_state['msg_rate'])} -1 {gemfire_url}")

data = requests.get(f"{gemfire_url}/queries/adhoc'", params={"q": top10query}).json()

totalPrimary = requests.get(f"{gemfire_url}/queries/adhoc'", params={"q": totalPrimaryCountQuery}).text

totalSecondary = requests.get(f"{gemfire_url}/queries/adhoc'", params={"q": totalSecondaryCountQuery}).text

logging.info(f"Top 10:\n{data}\nTotal Primary:\n{totalPrimary}\nTotal Secondary:\n{totalSecondary}")

col1, col2 = st.columns()

col1.metric("Total Primary", np.random.randint(100, 1000))

col2.metric("Total Secondary", np.random.randint(100, 1000))

# df = pd.DataFrame(np.random.randn(50, 5), columns=data.keys())

# df = pd.DataFrame(np.random.randn(50, 5), columns=['Claim ID', 'Name', 'Address', 'Date', 'Region'])

df = pd.read_sql_query('SELECT * FROM claims', engine)

st.dataframe(df)

# Refresh the screen at a configured interval
st_autorefresh(interval=5 * 1000, key="refresher")
