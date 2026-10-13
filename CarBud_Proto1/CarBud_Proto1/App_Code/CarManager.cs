using System.Data;
using System.Data.SqlClient;

namespace CarBud_Proto1
{
    public class CarManager
    {
        public static DataTable GetAllCars()
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_GetAllCars", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                SqlDataAdapter adapter = new SqlDataAdapter(cmd);
                DataTable table = new DataTable();
                adapter.Fill(table);
                return table;
            }
        }
    }
}