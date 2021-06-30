FROM quay.io/eduk8s/conda-environment:201203.022448.4bb682d

COPY --chown=1001:0 . /home/eduk8s/

# Install kubectl cli, helm cli, k9s
RUN mv /home/eduk8s/other/resources/bin/* /opt/eduk8s/bin && \
    mv /home/eduk8s/workshop /opt/workshop

RUN fix-permissions /home/eduk8s
