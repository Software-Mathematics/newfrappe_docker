# Adds the smerp_theme app (HealthCareUI look) on top of the built image.
#  - copies the app into the bench
#  - installs it editable so its hooks (app_include_css) are picked up
#  - symlinks its public/ into the baked assets dir, matching how the other
#    apps are linked, so /assets/smerp_theme/css/smerp_theme.css resolves.
# The site-level install (bench install-app smerp_theme) is done after the
# containers come up on this image.
FROM smerp:latest
USER frappe
WORKDIR /home/frappe/frappe-bench

COPY --chown=frappe:frappe smerp_theme /home/frappe/frappe-bench/apps/smerp_theme

RUN ./env/bin/pip install -e apps/smerp_theme \
 && ln -sfn /home/frappe/frappe-bench/apps/smerp_theme/smerp_theme/public \
            /home/frappe/frappe-bench/assets/smerp_theme
