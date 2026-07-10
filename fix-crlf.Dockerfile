# The frappe_docker repo was checked out on Windows, so the entrypoint scripts
# copied into the image have CRLF line endings. The `#!/bin/bash\r` shebang makes
# Linux fail with "no such file or directory". Normalize to LF.
FROM smerp:latest
USER root
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/start.sh \
 && chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/start.sh
USER frappe
