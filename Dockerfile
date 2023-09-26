FROM pennlinc/atlaspack:0.0.4 as atlaspack
FROM ubuntu:bionic-20220531

# Pre-cache neurodebian key
COPY docker/files/neurodebian.gpg /usr/local/etc/neurodebian.gpg

# Download atlases from AtlasPack
RUN mkdir /AtlasPack
COPY --from=atlaspack /AtlasPack/tpl-fsLR_*.dlabel.nii /AtlasPack/
COPY --from=atlaspack /AtlasPack/tpl-MNI152NLin6Asym_*.nii.gz /AtlasPack/
COPY --from=atlaspack /AtlasPack/atlas-4S*.tsv /AtlasPack/
COPY --from=atlaspack /AtlasPack/*.json /AtlasPack/

# Prepare environment
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-utils \
        autoconf \
        bc \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        cython3 \
        dc \
        file \
        freeglut3-dev \
        g++ \
        gcc \
        git \
        gnupg-agent \
        imagemagick \
        libboost-all-dev \
        libeigen3-dev \
        libfftw3-dev libtiff5-dev \
        libfontconfig1 \
        libfreetype6 \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        libgomp1 \
        libice6 \
        libopenblas-base \
        libqt5opengl5-dev \
        libqt5svg5* \
        libtool \
        libxcursor1 \
        libxft2 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        libxt6 \
        make \
        mesa-utils \
        pkg-config \
        python \
        python-numpy \
        software-properties-common \
        unzip \
        wget \
        xvfb \
        zlib1g \
        zlib1g-dev \
        && \
    curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install -y --no-install-recommends \
        nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV OS="Linux" \
    FIX_VERTEX_AREA=""

# Install miniconda
RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-py38_4.9.2-Linux-x86_64.sh && \
    bash Miniconda3-py38_4.9.2-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda3-py38_4.9.2-Linux-x86_64.sh

# Set CPATH for packages relying on compiled libs (e.g. indexed_gzip)
ENV PATH="/usr/local/miniconda/bin:$PATH" \
    CPATH="/usr/local/miniconda/include:$CPATH" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONNOUSERSITE=1

# Install basic Python dependencies for ASLPrep conda environment.
# The ASLPrep Dockerfile will install more tailored dependencies.
RUN conda install -y \
        python=3.10 \
        conda-build \
        pip=23 \
        matplotlib \
        mkl=2021.2 \
        mkl-service=2.3 \
        libxml2=2.9.8 \
        libxslt=1.1.32 \
        graphviz=2.40.1 \
        zlib \
        --channel conda-forge ; \
        sync && \
    chmod -R a+rX /usr/local/miniconda; sync && \
    chmod +x /usr/local/miniconda/bin/*; sync && \
    conda build purge-all; sync && \
    conda clean -tipsy; sync

# Install FSL from old ASLPrep version
# Based on https://github.com/ReproNim/neurodocker/blob/a87693e5676e7c4d272bc4eb8285f9232860d0ff/neurodocker/templates/fsl.yaml
RUN curl -fsSL https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/releases/fslinstaller.py | python3 - -d /opt/fsl-6.0.7.1 -V 6.0.7.1
ENV FSLDIR="/opt/fsl-6.0.7.1" \
    PATH="$PATH:/opt/fsl-6.0.7.1/bin" \
    FSLOUTPUTTYPE="NIFTI_GZ" \
    FSLMULTIFILEQUIT="TRUE" \
    FSLTCLSH="/opt/fsl-6.0.7.1/bin/fsltclsh" \
    FSLWISH="/opt/fsl-6.0.7.1/bin/fslwish" \
    FSLLOCKDIR="" \
    FSLMACHINELIST="" \
    FSLREMOTECALL="" \
    FSLGECUDAQ="cuda.q"

# Install Neurodebian packages (AFNI, Connectome Workbench, git)
RUN curl -sSL "http://neuro.debian.net/lists/$( lsb_release -c | cut -f2 ).us-ca.full" >> /etc/apt/sources.list.d/neurodebian.sources.list && \
    apt-key add /usr/local/etc/neurodebian.gpg && \
    (apt-key adv --refresh-keys --keyserver hkp://ha.pool.sks-keyservers.net 0xA5D32F012649A5A9 || true)

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        afni=18.0.05+git24-gb25b21054~dfsg.1-1~nd17.10+1+nd18.04+1 \
        connectome-workbench=1.5.0-1~nd18.04+1 \
        git-annex-standalone && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure AFNI
ENV AFNI_MODELPATH="/usr/lib/afni/models" \
    AFNI_IMSAVE_WARNINGS="NO" \
    AFNI_TTATLAS_DATASET="/usr/share/afni/atlases" \
    AFNI_PLUGINPATH="/usr/lib/afni/plugins"

ENV PATH="/usr/lib/afni/bin:$PATH"

# Install FreeSurfer
# Only grab elements we need for ASLPrep
RUN curl -sSL https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.1/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.1.tar.gz | tar zxv --no-same-owner -C /opt \
    --exclude="freesurfer/diffusion" \
    --exclude="freesurfer/docs" \
    --exclude="freesurfer/fsfast" \
    --exclude="freesurfer/lib/cuda" \
    --exclude="freesurfer/lib/qt" \
    --exclude="freesurfer/matlab" \
    --exclude="freesurfer/mni/share/man" \
    --exclude="freesurfer/subjects/fsaverage_sym" \
    --exclude="freesurfer/subjects/fsaverage3" \
    --exclude="freesurfer/subjects/fsaverage4" \
    --exclude="freesurfer/subjects/cvs_avg35" \
    --exclude="freesurfer/subjects/cvs_avg35_inMNI152" \
    --exclude="freesurfer/subjects/bert" \
    --exclude="freesurfer/subjects/lh.EC_average" \
    --exclude="freesurfer/subjects/rh.EC_average" \
    --exclude="freesurfer/subjects/sample-*.mgz" \
    --exclude="freesurfer/subjects/V1_average" \
    --exclude="freesurfer/trctrain"

ENV FSF_OUTPUT_FORMAT="nii.gz" \
    FREESURFER_HOME="/opt/freesurfer"

ENV SUBJECTS_DIR="$FREESURFER_HOME/subjects" \
    FUNCTIONALS_DIR="$FREESURFER_HOME/sessions" \
    MNI_DIR="$FREESURFER_HOME/mni" \
    LOCAL_DIR="$FREESURFER_HOME/local" \
    MINC_BIN_DIR="$FREESURFER_HOME/mni/bin" \
    MINC_LIB_DIR="$FREESURFER_HOME/mni/lib" \
    MNI_DATAPATH="$FREESURFER_HOME/mni/data"

ENV PERL5LIB="$MINC_LIB_DIR/perl5/5.8.5" \
    MNI_PERL5LIB="$MINC_LIB_DIR/perl5/5.8.5" \
    PATH="$FREESURFER_HOME/bin:$FREESURFER_HOME/tktools:$MINC_BIN_DIR:$PATH"

# Install ANTs latest from source
ENV ANTSPATH=/usr/lib/ants
RUN mkdir -p $ANTSPATH && \
    curl -sSL "https://dl.dropbox.com/s/gwf51ykkk5bifyj/ants-Linux-centos6_x86_64-v2.3.4.tar.gz" \
    | tar -xzC $ANTSPATH --strip-components 1
ENV PATH=$ANTSPATH:$PATH

# Install Convert3D
RUN echo "Downloading C3D ..." \
    && mkdir /opt/c3d \
    && curl -sSL --retry 5 https://sourceforge.net/projects/c3d/files/c3d/1.0.0/c3d-1.0.0-Linux-x86_64.tar.gz/download \
    | tar -xzC /opt/c3d --strip-components=1
ENV C3DPATH=/opt/c3d/bin \
    PATH=/opt/c3d/bin:$PATH

# Install SVGO
RUN curl -sL https://deb.nodesource.com/setup_12.x  | bash -
RUN apt-get -y install nodejs
RUN npm install -g svgo

# Install bids-validator
RUN npm install -g bids-validator@1.8.4

# Unless otherwise specified each process should only use one thread - nipype
# will handle parallelization
ENV MKL_NUM_THREADS=1 \
    OMP_NUM_THREADS=1

# Create a shared $HOME directory
RUN useradd -m -s /bin/bash -G users aslprep
WORKDIR /home/aslprep
ENV HOME="/home/aslprep"

# Precache fonts, set "Agg" as default backend for matplotlib
RUN python -c "from matplotlib import font_manager" && \
    sed -i 's/\(backend *: \).*$/\1Agg/g' $( python -c "import matplotlib; print(matplotlib.matplotlib_fname())" )

# Precache commonly-used templates
RUN pip install --no-cache-dir "templateflow ~= 0.8.1" && \
    python -c "from templateflow import api as tfapi; \
               tfapi.get(['MNI152NLin2009cAsym', 'MNI152NLin6Asym'], atlas=None, resolution=[1, 2], desc=['brain', None], extension=['.nii', '.nii.gz']); \
               tfapi.get('OASIS30ANTs', extension=['.nii', '.nii.gz']);" && \
    find $HOME/.cache/templateflow -type d -exec chmod go=u {} + && \
    find $HOME/.cache/templateflow -type f -exec chmod go=u {} +

# Install pandoc (for HTML/LaTeX reports)
RUN curl -o pandoc-2.2.2.1-1-amd64.deb -sSL "https://github.com/jgm/pandoc/releases/download/2.2.2.1/pandoc-2.2.2.1-1-amd64.deb" && \
    dpkg -i pandoc-2.2.2.1-1-amd64.deb && \
    rm pandoc-2.2.2.1-1-amd64.deb

RUN find $HOME -type d -exec chmod go=u {} + && \
    find $HOME -type f -exec chmod go=u {} + && \
    rm -rf $HOME/.npm $HOME/.conda $HOME/.empty

RUN ldconfig
WORKDIR /tmp/
