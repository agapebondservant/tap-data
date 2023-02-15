# ARG BASE_IMAGE=quay.io/eduk8s/conda-environment:201203.022448.4bb682d
# ARG BASE_IMAGE=oawofolu/learning-platform-image:v1
ARG BASE_IMAGE=registry.tanzu.vmware.com/tanzu-application-platform/tap-packages@sha256:681ef8d2e6fc8414b3783e4de424adbfabf2aa0126e34fa7dcd07dab61e55a89
ARG LEGACY_IMAGE_REPOSITORY=quay.io/eduk8s
ARG IMAGE_REPOSITORY=quay.io/eduk8s

FROM ${LEGACY_IMAGE_REPOSITORY}/pkgs-java-tools:210217.084517.d583aff as java-tools
FROM ${LEGACY_IMAGE_REPOSITORY}/conda-environment:201203.022448.4bb682d as conda-tools
FROM ${BASE_IMAGE}

#Install conda
ENV CONDA_DIR=/opt/conda \
    PATH=/opt/conda/bin:$PATH
ENV MINICONDA_VERSION=4.8.2 \
    MINICONDA_MD5=87e77f097f6ebb5127c77662dfc3165e \
    CONDA_VERSION=4.8.2
RUN mkdir -p $CONDA_DIR && \
    cd /tmp && \
    curl -sL -o install-miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-py37_${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "${MINICONDA_MD5} install-miniconda.sh" | md5sum -c - && \
    /bin/bash install-miniconda.sh -f -b -p $CONDA_DIR && \
    rm install-miniconda.sh && \
    echo "conda ${CONDA_VERSION}" >> $CONDA_DIR/conda-meta/pinned && \
    conda config --system --prepend channels conda-forge && \
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    conda config --system --set channel_priority strict && \
    conda list python | grep '^python ' | tr -s ' ' | cut -d '.' -f 1,2 | sed 's/$/.*/' >> $CONDA_DIR/conda-meta/pinned && \
    conda install --quiet --yes conda && \
    conda install --quiet --yes pip && \
    conda update --all --quiet --yes && \
    conda clean --all -f -y && \
    rm -rf /home/eduk8s/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/eduk8s
RUN pip install tqdm --upgrade && \
    conda install --quiet --yes \
    'notebook=6.0.3' \
    'jupyterlab=2.0.1' && \
    conda clean --all -f -y && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/eduk8s/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/eduk8s

# Copy from conda, java stages
COPY --from=conda-tools --chown=1001:0 /opt/conda /opt/conda
COPY --chown=1001:0 workshop /opt/eduk8s/workshop
COPY --from=java-tools --chown=1001:0 /opt/jdk11 /opt/java
COPY --from=java-tools --chown=1001:0 /opt/gradle /opt/gradle
COPY --from=java-tools --chown=1001:0 /opt/maven /opt/maven
COPY --from=java-tools --chown=1001:0 /opt/code-server/extensions/.  /opt/code-server/extensions/
COPY --from=java-tools --chown=1001:0 /home/eduk8s/. /home/eduk8s/
COPY --from=java-tools --chown=1001:0 /opt/eduk8s/. /opt/eduk8s/
COPY --chown=1001:0 . /home/eduk8s/

# Install additional Python libraries
RUN curl -sL -o get-pip.py https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py pip==21.0.1 && \
    pip install Faker && \
# Install krew
    /home/eduk8s/other/resources/krew/install_krew.sh && \
    mv /home/eduk8s/.krew/bin/* /opt/eduk8s/bin && \
# Install kubectl cli, helm cli, k9s, yq, flux, argocd, tanzu
    tar xzf /home/eduk8s/other/resources/bin/argocd.tar.gz && \
    mv /home/eduk8s/other/resources/bin/* /opt/eduk8s/bin
    # && mv /home/eduk8s/workshop /opt/workshop

# Set environment variables
ENV PATH=/opt/java/bin:/opt/gradle/bin:/opt/maven/bin:$PATH \
    JAVA_HOME=/opt/java \
    M2_HOME=/opt/maven
ENV ENABLE_JUPYTERLAB=false

# Fix permissions
RUN fix-permissions /home/eduk8s
