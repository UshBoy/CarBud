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
        }
    }
}
