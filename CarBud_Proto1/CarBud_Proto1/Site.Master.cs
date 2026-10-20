using System;
using System.Web.UI;

namespace CarBud_Proto1
{
    // The shared layout: header, menu and footer for every page.
    // The menu changes depending on whether someone is logged in.
    public partial class SiteMaster : MasterPage
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            bool loggedIn = CurrentUser.IsLoggedIn;
            phLoggedIn.Visible = loggedIn;
            phLoggedOut.Visible = !loggedIn;

            if (loggedIn)
            {
                litName.Text = Server.HtmlEncode(CurrentUser.FullName);
            }
            else
            {
                // "Log in" and "Sign up" in the menu bring the visitor back to this page afterwards
                string backTo = PageToReturnTo();
                lnkNavLogin.NavigateUrl = CurrentUser.WithReturnUrl("Login.aspx", backTo);
                lnkNavRegister.NavigateUrl = CurrentUser.WithReturnUrl("Register.aspx", backTo);
            }
        }

        // Which page should the visitor come back to after logging in?
        private string PageToReturnTo()
        {
            string page = Request.AppRelativeCurrentExecutionFilePath ?? "";

            // On the Log in or Sign up page itself: keep the page they were already going back to
            if (page.EndsWith("Login.aspx", StringComparison.OrdinalIgnoreCase)
                || page.EndsWith("Register.aspx", StringComparison.OrdinalIgnoreCase))
            {
                return Request.QueryString["ReturnUrl"];
            }

            // The home page is the default anyway
            if (page.EndsWith("Default.aspx", StringComparison.OrdinalIgnoreCase) || page == "~/")
            {
                return null;
            }

            return Request.RawUrl;
        }
    }
}
