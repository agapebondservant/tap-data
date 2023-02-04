import streamlit as st
import logging
from app.analytics import cifar_cnn
from io import StringIO
from PIL import Image

# Initializations
st.set_option('deprecation.showPyplotGlobalUse', False)

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

span.predictedlabel{
    font-size: 1.6em;
    color: green;
}

@keyframes blinker {
  50% {
    opacity: 0;
  }
}
</style>
""", unsafe_allow_html=True)

st.header('Tanzu/Vmware Imaging Analytics Demo')

st.text('Demonstration of image pattern detection using neutral networks and Vmware Tanzu')

tab1, tab2 = st.tabs(["CIFAR-10", "MRI"])

# CIFAR-10
with tab1:
    uploaded_file = st.file_uploader("Choose an image", key="upl_cifar")
    if uploaded_file is not None:
        cifar_img = Image.open(uploaded_file)
        col1, col2 = st.columns(2)
        with col1:
            st.image(cifar_img, width=200)
        with col2:
            st.markdown("Predicted Label:<br/> <span class='predictedlabel'>None</span>",
                        unsafe_allow_html=True)

# MRI
with tab2:
    uploaded_file = st.file_uploader("Choose an image", key="upl_mri")
    if uploaded_file is not None:
        mri_img = Image.open(uploaded_file)
        col1, col2 = st.columns(2)
        with col1:
            st.image(mri_img, width=200)
        with col2:
            st.markdown("Predicted Label:<br/> <span class='predictedlabel'>None</span>",
                        unsafe_allow_html=True)
