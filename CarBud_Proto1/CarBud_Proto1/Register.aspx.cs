using System;
using System.Web.UI;

namespace CarBud_Proto1
{
    // Sign-up page: creates an account, then logs the new customer in
    public partial class Register : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            // Already logged in? Then there is nothing to do here.
            if (CurrentUser.IsLoggedIn)
            {
                Response.Redirect("Default.aspx");
            }
        }

        protected void btnRegister_Click(object sender, EventArgs e)
        {
            // Stop if any of the checks on the form failed
            if (!Page.IsValid)
            {
                return;
            }

            string name = txtName.Text.Trim();
            string email = txtEmail.Text.Trim();

            int newUserId = UserManager.Register(name, email, txtPassword.Text);

            if (newUserId == -1)
            {
                ShowMessage("An account with this email already exists. Please log in instead.");
                return;
            }

            // Log the new customer in straight away
            UserInfo user = new UserInfo();
            user.UserID = newUserId;
            user.FullName = name;
            user.Email = email.ToLowerInvariant();
            user.IsAdmin = false;
            CurrentUser.SignIn(user);

            Response.Redirect(CurrentUser.SafeReturnUrl(Request.QueryString["ReturnUrl"]));
        }

        private void ShowMessage(string text)
        {
            lblMessage.Text = Server.HtmlEncode(text);
            lblMessage.Visible = true;
        }
    }
}
