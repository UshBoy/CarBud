using System;
using System.Web.UI;

namespace CarBud_Proto1
{
    // Logs the customer out and goes back to the home page
    public partial class Logout : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            CurrentUser.SignOut();
            Response.Redirect("Default.aspx");
        }
    }
}
