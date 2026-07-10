# CRLF fix for the clean "original" image (entrypoint scripts checked out on
# Windows have CRLF, which breaks the Linux shebang). Produces smerp-original:latest.
FROM smerp-original-base:latest
USER root
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/start.sh \
 && chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/start.sh
USER frappe
