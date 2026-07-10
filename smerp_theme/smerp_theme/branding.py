import frappe

# The name shown in the login heading ("Login to Healthcare") and app title.
APP_NAME = "Healthcare"
# Medharva logo — served from this app's public folder.
APP_LOGO = "/assets/smerp_theme/images/medharva-logo.svg"
# Splash (desk loading screen after login) + browser-tab favicon.
SPLASH = "/assets/smerp_theme/images/medharva-logo.png"
FAVICON = "/assets/smerp_theme/images/medharva-logo.png"


def apply_branding():
    """Apply Healthcare/Medharva branding. Idempotent — safe on every migrate.

    - app_name drives the login heading ("Login to {app_name}") which login.py
      resolves as Website Settings.app_name or System Settings.app_name.
    - app_logo drives the navbar brand and the login-page logo. get_app_logo()
      checks Website Settings.app_logo first (the hook fallback is unreliable
      once >2 apps define app_logo_url), so we set it there and on Navbar Settings.
    """
    try:
        frappe.db.set_single_value("Website Settings", "app_name", APP_NAME)
        frappe.db.set_single_value("System Settings", "app_name", APP_NAME)
        frappe.db.set_single_value("Website Settings", "app_logo", APP_LOGO)
        frappe.db.set_single_value("Navbar Settings", "app_logo", APP_LOGO)
        # splash = the loading screen shown while the desk boots after login;
        # favicon = the browser tab icon. Both defaulted to Frappe's logo.
        frappe.db.set_single_value("Website Settings", "splash_image", SPLASH)
        frappe.db.set_single_value("Website Settings", "favicon", FAVICON)
        frappe.db.commit()
    except Exception:
        frappe.log_error(title="smerp_theme branding failed")
