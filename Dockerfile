###   Start by creating a "builder"   ###
# We'll compile all needed packages in the builder, and then
# we'll just get only what we need for the actual APP

# Use an official Python runtime as a parent image
FROM cbinyu/bidsapp_builder as builder

## install:
# -curl, gcc compiler     (needed to install pydeface)
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    curl \
    g++ \
  && apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y

###   Install Pydeface   ###


# Latest release: v1.1.0 (Dec. '18)

# Install pydeface from github:
RUN cd /tmp && \
    mkdir pydeface && \
    curl -sSL https://github.com/poldracklab/pydeface/archive/v1.1.0.tar.gz \
        | tar -vxz -C pydeface --strip-components=1 && \
    cd pydeface && \
    easy_install -Z ./ && \
    cd / && rm -rf /tmp/pydeface

# FOR FUTURE RELEASES:
# 1. installing using "python3 setup.py install", as suggested
#    in the pydeface documentation does not work, because it
#    installs some of the dependencies as zipped, and when you
#    call pydeface, it tries to unzip it to the PYTHON_EGG_CACHE,
#    which is set to /.cache (at least for a regular user, as opposed
#    to 'root').
#    My solution is to add the flag "zip_safe=False" to setup.py:
#    Another possibility would be to install using 'pip install .'
# 2. the "which('fsl')" occurs in the current "main" branch, not
#    in the v1.1.0 tag.  I'm leaving it here for future tags, but
#    right now it's harmless.
#
#RUN apt-get update -qq && apt-get install -y git-core && \
#    apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y
#RUN cd /tmp && \
#    git clone https://github.com/poldracklab/pydeface.git && \
#    cd pydeface && \
#    sed -i -e "s/which('fsl')/which('flirt')/" pydeface/utils.py && \
#    sed -i -e "s/\([ ]*\)package_data=[a-zA-Z0-9]*,$/&\n\1zip_safe=False,/" setup.py && \
#    python3 setup.py install && \
#    cd / && rm -rf /tmp/pydeface
       

#############

###  Now, get a new machine with only the essentials  ###
###       and add the BIDS-Apps wrapper (run.py)      ###
FROM cbinyu/bidsapp_builder as Application

ENV FSLDIR=/usr/local/fsl/ \
    FSLOUTPUTTYPE=NIFTI_GZ
ENV PATH=${FSLDIR}/bin:$PATH \
    LD_LIBRARY_PATH=${FSLDIR}:${LD_LIBRARY_PATH}

# Copy any extra python packages installed in the builder stage:
COPY --from=builder ./usr/local/lib/python3.5/site-packages/ /usr/local/lib/python3.5/site-packages/
COPY --from=builder ./usr/local/bin/           /usr/local/bin/
COPY --from=cbinyu/fsl6-core ./usr/local/fsl/bin/flirt  ${FSLDIR}/bin/
# The following copies both libraries to the $FSLDIR/lib folder:
COPY --from=cbinyu/fsl6-core ./usr/local/fsl/lib/libopenblas.so.0 \
                             ./usr/local/fsl/lib/libgfortran.so.3 \
			            ${FSLDIR}/lib/
# Copy an extra library needed by FSL:
COPY --from=cbinyu/fsl6-core ./usr/lib/x86_64-linux-gnu/libquadmath.so.0     \
                             ./usr/lib/x86_64-linux-gnu/libquadmath.so.0.0.0 \
                                    /usr/lib/x86_64-linux-gnu/

COPY run.py version /
RUN chmod a+rx /run.py /version

ENTRYPOINT ["/run.py"]
