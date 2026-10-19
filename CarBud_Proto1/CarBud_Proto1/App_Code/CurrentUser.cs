using System.Web;
using System.Web.SessionState;
using System.Web.UI;

namespace CarBud_Proto1
{
    // Remembers who is logged in, using the Session.
    // Any page can ask: CurrentUser.IsLoggedIn, CurrentUser.UserID, CurrentUser.FullName, CurrentUser.IsAdmin.
    public static class CurrentUser
    {
        private static HttpSessionState Session
        {
            get { return HttpContext.Current.Session; }
        }

        public static void SignIn(UserInfo user)
        {
            Session["UserID"] = user.UserID;
            Session["FullName"] = user.FullName;
            Session["IsAdmin"] = user.IsAdmin;
        }

        public static void SignOut()
        {
            Session.Clear();
            Session.Abandon();
        }

        public static bool IsLoggedIn
        {
            get { return Session != null && Session["UserID"] != null; }
        }

        public static int UserID
        {
            get { return IsLoggedIn ? (int)Session["UserID"] : 0; }
        }

        public static string FullName
        {
            get { return IsLoggedIn ? (string)Session["FullName"] : ""; }
        }

        public static bool IsAdmin
        {
            get { return IsLoggedIn && (bool)Session["IsAdmin"]; }
        }

        // Call this at the top of a page that needs a logged-in customer.
        // If nobody is logged in, it sends them to the Log in page, and back here afterwards.
        public static void RequireLogin(Page page)
        {
            if (!IsLoggedIn)
            {
                string returnUrl = HttpUtility.UrlEncode(page.Request.RawUrl);
                page.Response.Redirect("Login.aspx?ReturnUrl=" + returnUrl);
            }
        }

        // Only allows return addresses inside this website, so a link cannot send people to another site.
        public static string SafeReturnUrl(string url)
        {
            if (string.IsNullOrEmpty(url)
                || url.StartsWith("//")
                || url.StartsWith("\\")
                || url.StartsWith("/\\")
                || url.Contains(":"))
            {
                return "Default.aspx";
            }
            return url;
        }
    }
}
