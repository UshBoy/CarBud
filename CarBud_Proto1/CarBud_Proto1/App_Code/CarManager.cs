using System;
using System.Data;
using System.Data.SqlClient;

namespace CarBud_Proto1
{
    // Middle tier for cars. Every method calls a stored procedure (no SQL in the C# code).
    public class CarManager
    {
        // All available cars (used by the TestCars page)
        public static DataTable GetAllCars()
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_GetAllCars", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                return FillTable(cmd);
            }
        }

        // The list of car types, for the filter drop-down
        public static DataTable GetCarTypes()
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_GetCarTypes", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                return FillTable(cmd);
            }
        }

        // Cars that match the filters. Pass null to ignore a filter.
        public static DataTable SearchCars(string carType, int? maxPrice, int? minSeats)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_SearchCars", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@CarType", SqlDbType.NVarChar, 30).Value = (object)carType ?? DBNull.Value;
                cmd.Parameters.Add("@MaxPrice", SqlDbType.Int).Value = (object)maxPrice ?? DBNull.Value;
                cmd.Parameters.Add("@MinSeats", SqlDbType.Int).Value = (object)minSeats ?? DBNull.Value;
                return FillTable(cmd);
            }
        }

        // One car, or null if it does not exist or is hidden
        public static DataRow GetCarByID(int carId)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_GetCarByID", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@CarID", SqlDbType.Int).Value = carId;
                DataTable table = FillTable(cmd);
                return table.Rows.Count > 0 ? table.Rows[0] : null;
            }
        }

        // Runs the command and returns the rows as a table
        private static DataTable FillTable(SqlCommand cmd)
        {
            using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
            {
                DataTable table = new DataTable();
                adapter.Fill(table);
                return table;
            }
        }
    }
}
