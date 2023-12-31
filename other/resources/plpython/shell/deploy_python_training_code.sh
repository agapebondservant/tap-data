ssh -i ${SCP_PEM_PATH} ${USER}@${HOST} -o "StrictHostKeyChecking=no" "if [ -z \"$OVERRIDE_VENDORED_DEPS\" ] && [ -d \"${SHARED_PATH}/mlapp\" ]; \
                   then echo "Skipping reinstall of vendored dependencies - OVERRIDE_VENDORED_DEPS is empty";
                   else
                   rm -rf ${SHARED_PATH}/mlapp ${SHARED_PATH}/mlappbase ${SHARED_PATH}/config; \
                   git clone ${MLPIPELINE_GIT_REPO} ${SHARED_PATH}/mlapp; \
                   mv ${SHARED_PATH}/mlapp/app ${SHARED_PATH}/mlapp/base_app; \

                   curl -o vendor.tar.gz ${PYFUNC_VENDOR_URI}; \
                   mkdir -p ${SHARED_PATH}/mlapp/_vendor; \
                   tar -xvzf vendor.tar.gz -C ${SHARED_PATH}/mlapp/_vendor --strip-components=1;
                   fi;"