FROM busybox:1.35.0-uclibc as busybox

FROM argoproj/argocli
COPY --from=busybox /bin/sh /bin/sh
COPY --from=busybox /bin/mkdir /bin/mkdir
COPY --from=busybox /bin/cat /bin/cat

ENTRYPOINT ["/bin/sh"]