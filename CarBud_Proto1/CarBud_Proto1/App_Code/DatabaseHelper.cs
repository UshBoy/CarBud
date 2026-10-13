using System.Configuration;
using System.Data.SqlClient;

namespace CarBud_Proto1
{
    public static class DatabaseHelper
    {
        public static SqlConnection GetConnection()
        {
            string cs = ConfigurationManager
                .ConnectionStrings["CarBudDB"].ConnectionString;
            return new SqlConnection(cs);
        }
    }
}