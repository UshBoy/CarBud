using System;
using System.Data;
using System.Globalization;
using System.Web;
using System.Web.UI;

namespace CarBud_Proto1
{
    // Shows one car and lets a logged-in customer book it
    public partial class CarDetails : Page
    {
        private int carId;

        protected void Page_Load(object sender, EventArgs e)
        {
            // Which car? It comes from the address, e.g. CarDetails.aspx?id=8
            DataRow car = null;
            if (int.TryParse(Request.QueryString["id"], out carId))
            {
                car = CarManager.GetCarByID(carId);
            }

            if (car == null)
            {
                pnlNotFound.Visible = true;
                pnlCar.Visible = false;
                return;
            }

            ShowCar(car);

            // Did CarBud recommend this car in the visitor's latest chat? Then show a small badge.
            pnlFromChat.Visible = ChatManager.GetChatSessionForCar(carId).HasValue;

            // Logged in: show the booking form. Not logged in: show the "log in to book" box.
            bool loggedIn = CurrentUser.IsLoggedIn;
            pnlBookForm.Visible = loggedIn;
            pnlLoginFirst.Visible = !loggedIn;

            if (!IsPostBack)
            {
                string backHere = HttpUtility.UrlEncode(Request.RawUrl);
                lnkLogin.NavigateUrl = "Login.aspx?ReturnUrl=" + backHere;
                lnkRegister.NavigateUrl = "Register.aspx?ReturnUrl=" + backHere;

                // The calendar will not let customers pick days in the past
                txtStart.Attributes["min"] = DateTime.Today.ToString("yyyy-MM-dd");
                txtEnd.Attributes["min"] = DateTime.Today.AddDays(1).ToString("yyyy-MM-dd");
            }
        }

        private void ShowCar(DataRow car)
        {
            litType.Text = Server.HtmlEncode(car["CarType"].ToString());
            litTitle.Text = Server.HtmlEncode(car["Make"] + " " + car["Model"]);
            litPrice.Text = car["PricePerDay"].ToString();
            litSeats.Text = car["Seats"].ToString();
            litBoot.Text = car["BootLitres"].ToString();
            litFuel.Text = Server.HtmlEncode(car["FuelType"].ToString());
            litComfort.Text = car["ComfortRating"].ToString();
            hfPrice.Value = car["PricePerDay"].ToString();
        }

        protected void btnBook_Click(object sender, EventArgs e)
        {
            if (!CurrentUser.IsLoggedIn)
            {
                CurrentUser.RequireLogin(this);
                return;
            }

            if (!Page.IsValid)
            {
                return;
            }

            DateTime startDate;
            DateTime endDate;
            if (!TryReadDate(txtStart.Text, out startDate) || !TryReadDate(txtEnd.Text, out endDate))
            {
                ShowError("Please choose both dates.");
                return;
            }

            // If CarBud recommended this car, link the booking to that chat (for measuring the chatbot)
            int? chatSessionId = ChatManager.GetChatSessionForCar(carId);

            // The database checks the dates, checks the car is free, and works out the price
            BookingResult result = BookingManager.CreateBooking(CurrentUser.UserID, carId, startDate, endDate, chatSessionId);

            if (!result.Success)
            {
                ShowError(result.Message);
                return;
            }

            // Go to My Bookings. Moving to a new page means refreshing the browser cannot book twice.
            Response.Redirect("MyBookings.aspx?new=" + result.Result);
        }

        // The date boxes send dates in the format 2026-10-25
        private static bool TryReadDate(string text, out DateTime date)
        {
            return DateTime.TryParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out date);
        }

        private void ShowError(string text)
        {
            lblBookMessage.Text = Server.HtmlEncode(text);
            lblBookMessage.Visible = true;
        }
    }
}
