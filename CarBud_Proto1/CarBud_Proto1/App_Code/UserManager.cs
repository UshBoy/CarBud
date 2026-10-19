using System;
using System.Data;
using System.Data.SqlClient;
using System.Security.Cryptography;

namespace CarBud_Proto1
{
    // The details we keep about a logged-in user
    public class UserInfo
    {
        public int UserID { get; set; }
        public string FullName { get; set; }
        public string Email { get; set; }
        public bool IsAdmin { get; set; }
    }

    // Middle tier for customer accounts: sign-up and log-in.
    // Passwords are never stored. We store a hash: a one-way "fingerprint" of the password,
    // made with PBKDF2 (SHA-256, 100,000 rounds) and a random salt that is different for every user.
    public class UserManager
    {
        private const int SaltSize = 16;      // bytes
        private const int HashSize = 32;      // bytes
        private const int Iterations = 100000;

        // Creates an account. Returns the new UserID, or -1 if the email is already registered.
        public static int Register(string fullName, string email, string password)
        {
            byte[] salt = CreateSalt();
            byte[] hash = HashPassword(password, salt);

            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_RegisterUser", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@FullName", SqlDbType.NVarChar, 100).Value = fullName.Trim();
                cmd.Parameters.Add("@Email", SqlDbType.NVarChar, 150).Value = email.Trim().ToLowerInvariant();
                cmd.Parameters.Add("@PasswordHash", SqlDbType.VarBinary, HashSize).Value = hash;
                cmd.Parameters.Add("@PasswordSalt", SqlDbType.VarBinary, SaltSize).Value = salt;

                SqlParameter newUserId = cmd.Parameters.Add("@NewUserID", SqlDbType.Int);
                newUserId.Direction = ParameterDirection.Output;

                con.Open();
                cmd.ExecuteNonQuery();
                return (int)newUserId.Value;
            }
        }

        // Checks an email and password. Returns the user if they are right, otherwise null.
        public static UserInfo Login(string email, string password)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_GetUserForLogin", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@Email", SqlDbType.NVarChar, 150).Value = email.Trim().ToLowerInvariant();

                con.Open();
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    if (!reader.Read())
                    {
                        return null;   // no account with this email
                    }

                    byte[] storedHash = (byte[])reader["PasswordHash"];
                    byte[] salt = (byte[])reader["PasswordSalt"];
                    byte[] attemptHash = HashPassword(password, salt);

                    if (!HashesMatch(storedHash, attemptHash))
                    {
                        return null;   // wrong password
                    }

                    UserInfo user = new UserInfo();
                    user.UserID = (int)reader["UserID"];
                    user.FullName = (string)reader["FullName"];
                    user.Email = (string)reader["Email"];
                    user.IsAdmin = (bool)reader["IsAdmin"];
                    return user;
                }
            }
        }

        // A new random salt for each user
        private static byte[] CreateSalt()
        {
            byte[] salt = new byte[SaltSize];
            using (RNGCryptoServiceProvider rng = new RNGCryptoServiceProvider())
            {
                rng.GetBytes(salt);
            }
            return salt;
        }

        // Turns a password + salt into a hash
        private static byte[] HashPassword(string password, byte[] salt)
        {
            using (Rfc2898DeriveBytes pbkdf2 = new Rfc2898DeriveBytes(password, salt, Iterations, HashAlgorithmName.SHA256))
            {
                return pbkdf2.GetBytes(HashSize);
            }
        }

        // Compares two hashes. It always checks every byte, so the time taken
        // does not reveal how much of a guess was right.
        private static bool HashesMatch(byte[] a, byte[] b)
        {
            if (a.Length != b.Length)
            {
                return false;
            }
            int difference = 0;
            for (int i = 0; i < a.Length; i++)
            {
                difference |= a[i] ^ b[i];
            }
            return difference == 0;
        }
    }
}
