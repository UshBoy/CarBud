using System;
using System.Data;
using System.Data.SqlClient;

namespace CarBud_Proto1
{
    // What happened when we tried to book
    public class BookingResult
    {
        public int Result { get; set; }       // the new BookingID, or -1 / -2 / -3
        public int TotalPrice { get; set; }

        public bool Success
        {
            get { return Result > 0; }
        }

        // A message for the customer, in plain English
        public string Message
        {
            get
            {
                switch (Result)
                {
                    case -1: return "Please choose a pick-up date from today onwards, and a return date after the pick-up date.";
                    case -2: return "Sorry, this car is not available.";
                    case -3: return "Sorry, this car is already booked for some of those days. Please choose other dates.";
                    default: return Result > 0 ? "Your booking is confirmed." : "Something went wrong. Please try again.";
                }
            }
        }
    }

    // Middle tier for bookings
    public class BookingManager
    {
        // Books a car. sessionId is the chatbot conversation that led here (null if the customer booked without the chatbot).
        public static BookingResult CreateBooking(int userId, int carId, DateTime startDate, DateTime endDate, int? sessionId)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_CreateBooking", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@UserID", SqlDbType.Int).Value = userId;
                cmd.Parameters.Add("@CarID", SqlDbType.Int).Value = carId;
                cmd.Parameters.Add("@StartDate", SqlDbType.Date).Value = startDate.Date;
                cmd.Parameters.Add("@EndDate", SqlDbType.Date).Value = endDate.Date;
                cmd.Parameters.Add("@SessionID", SqlDbType.Int).Value = (object)sessionId ?? DBNull.Value;

                SqlParameter result = cmd.Parameters.Add("@Result", SqlDbType.Int);
                result.Direction = ParameterDirection.Output;
                SqlParameter totalPrice = cmd.Parameters.Add("@TotalPrice", SqlDbType.Int);
                totalPrice.Direction = ParameterDirection.Output;

                con.Open();
                cmd.ExecuteNonQuery();

                BookingResult booking = new BookingResult();
                booking.Result = (int)result.Value;
                booking.TotalPrice = (int)totalPrice.Value;
                return booking;
            }
        }

        // A customer's own bookings, newest first
        public static DataTable GetBookingsByUser(int userId)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_GetBookingsByUser", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@UserID", SqlDbType.Int).Value = userId;

                using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
                {
                    DataTable table = new DataTable();
                    adapter.Fill(table);
                    return table;
                }
            }
        }

        // Cancels a booking. Returns true if it was cancelled.
        public static bool CancelBooking(int bookingId, int userId)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_CancelBooking", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@BookingID", SqlDbType.Int).Value = bookingId;
                cmd.Parameters.Add("@UserID", SqlDbType.Int).Value = userId;

                SqlParameter result = cmd.Parameters.Add("@Result", SqlDbType.Int);
                result.Direction = ParameterDirection.Output;

                con.Open();
                cmd.ExecuteNonQuery();
                return (int)result.Value == 1;
            }
        }
    }
}
