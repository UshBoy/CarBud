using System;
using System.Web.UI;

namespace CarBud_Proto1
{
    // Log-in page
    public partial class Login : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (CurrentUser.IsLoggedIn)
            {
                Response.Redirect("Default.aspx");
            }

            // "Create an account" keeps the page the visitor should come back to
            lnkToRegister.NavigateUrl = CurrentUser.WithReturnUrl("Register.aspx", Request.QueryString["ReturnUrl"]);
        }

        protected void btnLogin_Click(object sender, EventArgs e)
        {
            if (!Page.IsValid)
            {
                return;
            }

            UserInfo user = UserManager.Login(txtEmail.Text, txtPassword.Text);

            if (user == null)
            {
                // Same message for a wrong email or a wrong password,
                // so the page does not reveal which emails have accounts.
                lblMessage.Text = "The email or password is not correct.";
                lblMessage.Visible = true;
                return;
            }

            CurrentUser.SignIn(user);
            Response.Redirect(CurrentUser.SafeReturnUrl(Request.QueryString["ReturnUrl"]));
        }
    }
}
