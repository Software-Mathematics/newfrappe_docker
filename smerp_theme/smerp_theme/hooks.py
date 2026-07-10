app_name = "smerp_theme"
app_title = "SMERP Theme"
app_publisher = "Software Mathematics"
app_description = "HealthCareUI-inspired theme for the ERPNext/SMERP desk"
app_email = "info@softwaremathematics.com"
app_license = "MIT"
app_version = "0.0.1"

# Inject the theme stylesheet into the desk (the /app SPA) and the
# website/login pages. The path resolves through the app's public folder,
# which is symlinked into sites/assets at container start.
app_include_css = "/assets/smerp_theme/css/smerp_theme.css"
web_include_css = "/assets/smerp_theme/css/smerp_theme.css"

# Medharva logo — drives the navbar brand AND the login-page logo
# (frappe's get_app_logo() uses the highest-priority app's app_logo_url,
# and smerp_theme loads last, so this wins).
app_logo_url = "/assets/smerp_theme/images/medharva-logo.svg"

# Set the app name to "Healthcare" so the login heading reads
# "Login to Healthcare". Runs when the theme app is installed and on migrate,
# so it's reproducible on a fresh build.
after_install = "smerp_theme.branding.apply_branding"
after_migrate = "smerp_theme.branding.apply_branding"
