using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;

namespace CarBud_Proto1
{
    // One clickable answer
    public class ChatOption
    {
        public int OptionID { get; set; }
        public string Text { get; set; }
        public int Value { get; set; }     // the number the scoring uses
    }

    // One question with its answers
    public class ChatQuestion
    {
        public int QuestionID { get; set; }
        public int Order { get; set; }     // 1 passengers, 2 distance, 3 luggage, 4 budget, 5 purpose
        public string Text { get; set; }
        public List<ChatOption> Options { get; set; }

        public ChatQuestion()
        {
            Options = new List<ChatOption>();
        }
    }

    // Middle tier for the chatbot: questions, saving each chat, and asking the scoring procedure for cars
    public class ChatManager
    {
        // The questions and their answers, read from the database (so new questions need no code changes)
        public static List<ChatQuestion> GetQuestions()
        {
            List<ChatQuestion> questions = new List<ChatQuestion>();

            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_GetChatQuestions", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                con.Open();
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    ChatQuestion current = null;
                    while (reader.Read())
                    {
                        int questionId = (int)reader["QuestionID"];
                        if (current == null || current.QuestionID != questionId)
                        {
                            current = new ChatQuestion();
                            current.QuestionID = questionId;
                            current.Order = (int)reader["QuestionOrder"];
                            current.Text = (string)reader["QuestionText"];
                            questions.Add(current);
                        }

                        ChatOption option = new ChatOption();
                        option.OptionID = (int)reader["OptionID"];
                        option.Text = (string)reader["OptionText"];
                        option.Value = (int)reader["OptionValue"];
                        current.Options.Add(option);
                    }
                }
            }
            return questions;
        }

        // The top cars for these answers, from the scoring procedure
        public static DataTable RecommendCars(int passengers, int distance, int luggage, int maxBudget, int purpose)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_RecommendCars", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@Passengers", SqlDbType.Int).Value = passengers;
                cmd.Parameters.Add("@Distance", SqlDbType.Int).Value = distance;
                cmd.Parameters.Add("@Luggage", SqlDbType.Int).Value = luggage;
                cmd.Parameters.Add("@MaxBudget", SqlDbType.Int).Value = maxBudget;
                cmd.Parameters.Add("@Purpose", SqlDbType.Int).Value = purpose;
                cmd.Parameters.Add("@TopN", SqlDbType.Int).Value = 3;

                using (SqlDataAdapter adapter = new SqlDataAdapter(cmd))
                {
                    DataTable table = new DataTable();
                    adapter.Fill(table);
                    return table;
                }
            }
        }

        // Starts a saved chat and returns its SessionID
        public static int CreateSession(string userNotes)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_CreateChatSession", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@UserNotes", SqlDbType.NVarChar, 500).Value =
                    string.IsNullOrWhiteSpace(userNotes) ? (object)DBNull.Value : userNotes;
                SqlParameter sessionId = cmd.Parameters.Add("@SessionID", SqlDbType.Int);
                sessionId.Direction = ParameterDirection.Output;

                con.Open();
                cmd.ExecuteNonQuery();
                return (int)sessionId.Value;
            }
        }

        public static void SaveAnswer(int sessionId, int questionId, int optionId)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_SaveSessionAnswer", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@SessionID", SqlDbType.Int).Value = sessionId;
                cmd.Parameters.Add("@QuestionID", SqlDbType.Int).Value = questionId;
                cmd.Parameters.Add("@OptionID", SqlDbType.Int).Value = optionId;
                con.Open();
                cmd.ExecuteNonQuery();
            }
        }

        public static void SaveRecommendation(int sessionId, int carId, int rank, int score, string explanation)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_SaveRecommendation", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@SessionID", SqlDbType.Int).Value = sessionId;
                cmd.Parameters.Add("@CarID", SqlDbType.Int).Value = carId;
                cmd.Parameters.Add("@RankPosition", SqlDbType.Int).Value = rank;
                cmd.Parameters.Add("@Score", SqlDbType.Int).Value = score;
                cmd.Parameters.Add("@Explanation", SqlDbType.NVarChar, -1).Value = (object)explanation ?? DBNull.Value;
                con.Open();
                cmd.ExecuteNonQuery();
            }
        }

        // Records which model answered ("fallback" if the AI was not used) and how long it took
        public static void FinishSession(int sessionId, string modelUsed, int responseMs)
        {
            using (SqlConnection con = DatabaseHelper.GetConnection())
            using (SqlCommand cmd = new SqlCommand("usp_FinishChatSession", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@SessionID", SqlDbType.Int).Value = sessionId;
                cmd.Parameters.Add("@ModelUsed", SqlDbType.NVarChar, 50).Value = modelUsed;
                cmd.Parameters.Add("@ResponseMs", SqlDbType.Int).Value = responseMs;
                con.Open();
                cmd.ExecuteNonQuery();
            }
        }

        // Remembers the latest chat in this visitor's Session, so a booking of a recommended car
        // can be linked to the chat (this lets us measure how many bookings came from CarBud).
        public static void RememberChat(int sessionId, List<int> recommendedCarIds)
        {
            HttpContext.Current.Session["ChatSessionID"] = sessionId;
            HttpContext.Current.Session["ChatCarIDs"] = recommendedCarIds;
        }

        // The chat that recommended this car, or null if it was not recommended in the latest chat
        public static int? GetChatSessionForCar(int carId)
        {
            if (HttpContext.Current == null || HttpContext.Current.Session == null)
            {
                return null;
            }
            List<int> carIds = HttpContext.Current.Session["ChatCarIDs"] as List<int>;
            object sessionId = HttpContext.Current.Session["ChatSessionID"];
            if (carIds != null && sessionId is int && carIds.Contains(carId))
            {
                return (int)sessionId;
            }
            return null;
        }
    }
}
