using System;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace CarBud_Proto1
{
    // A customer's own bookings, with a Cancel button for bookings that have not started yet
    public partial class MyBookings : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            // Only for logged-in customers
            CurrentUser.RequireLogin(this);

            if (!IsPostBack)
            {
                // Coming straight from a new booking? Then say so.
                int newBookingId;
                if (int.TryParse(Request.QueryString["new"], out newBookingId) && newBookingId > 0)
                {
                    ShowMessage("Your booking is confirmed. Your booking number is #" + newBookingId + ".", true);
                }

                LoadBookings();
            }
        }

        private void LoadBookings()
        {
            DataTable bookings = BookingManager.GetBookingsByUser(CurrentUser.UserID);
            rptBookings.DataSource = bookings;
            rptBookings.DataBind();

            rptBookings.Visible = bookings.Rows.Count > 0;
            pnlEmpty.Visible = bookings.Rows.Count == 0;
        }

        // Runs when a Cancel button in the list is clicked
        protected void rptBookings_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "CancelBooking")
            {
                return;
            }

            int bookingId = Convert.ToInt32(e.CommandArgument);

            // The database only cancels it if it belongs to this customer and has not started yet
            if (BookingManager.CancelBooking(bookingId, CurrentUser.UserID))
            {
                ShowMessage("Booking #" + bookingId + " has been cancelled.", true);
            }
            else
            {
                ShowMessage("Booking #" + bookingId + " could not be cancelled.", false);
            }

            LoadBookings();
        }

        // Decides whether a row gets a Cancel button
        protected bool CanCancel(object dataItem)
        {
            DataRowView row = (DataRowView)dataItem;
            return (string)row["BookingStatus"] == "Confirmed"
                && (DateTime)row["StartDate"] >= DateTime.Today;
        }

        private void ShowMessage(string text, bool good)
        {
            lblMessage.Text = Server.HtmlEncode(text);
            lblMessage.CssClass = good ? "message message-ok" : "message message-error";
            lblMessage.Visible = true;
        }
    }
}
