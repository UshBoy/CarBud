using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web.Script.Serialization;
using System.Web.UI;

namespace CarBud_Proto1
{
    // One question and answer in the conversation (shown again on the results screen)
    public class ChatLine
    {
        public string Question { get; set; }
        public string Answer { get; set; }
    }

    // One recommended car, ready to show
    public class RecommendationCard
    {
        public int CarID { get; set; }
        public string RankLabel { get; set; }
        public string Name { get; set; }
        public string CarType { get; set; }
        public int Seats { get; set; }
        public int BootLitres { get; set; }
        public string FuelType { get; set; }
        public int Comfort { get; set; }
        public int PricePerDay { get; set; }
        public int Score { get; set; }
        public string Reason { get; set; }
    }

    // The CarBud chat page
    public partial class Chat : Page
    {
        private List<ChatQuestion> questions;

        protected void Page_Load(object sender, EventArgs e)
        {
            // Always read the questions from the database (never trust the browser's copy)
            questions = ChatManager.GetQuestions();

            if (!IsPostBack)
            {
                // Send the questions to the browser as JSON for the chat script
                var forBrowser = questions.Select(q => new
                {
                    id = q.QuestionID,
                    text = q.Text,
                    options = q.Options.Select(o => new { id = o.OptionID, text = o.Text }).ToList()
                }).ToList();
                hfQuestions.Value = new JavaScriptSerializer().Serialize(forBrowser);
            }
        }

        // Runs when the customer has answered everything
        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            // 1. Read and check the answers: exactly one valid choice for each question, in order
            List<ChatOption> chosen = ReadAnswers(hfAnswers.Value);
            if (chosen == null)
            {
                ShowError("Sorry, something went wrong with your answers.");
                return;
            }

            string notes = (hfNotes.Value ?? "").Replace("<", "").Replace(">", "").Trim();
            if (notes.Length > 300)
            {
                notes = notes.Substring(0, 300);
            }

            // The scoring uses the question order: 1 passengers, 2 distance, 3 luggage, 4 budget, 5 purpose
            TripAnswers trip = new TripAnswers();
            trip.Passengers = AnswerFor(1, chosen).Text;
            trip.Distance = AnswerFor(2, chosen).Text;
            trip.Luggage = AnswerFor(3, chosen).Text;
            trip.Budget = AnswerFor(4, chosen).Text;
            trip.Purpose = AnswerFor(5, chosen).Text;
            trip.DistanceValue = AnswerFor(2, chosen).Value;
            trip.BudgetValue = AnswerFor(4, chosen).Value;
            trip.Notes = notes;

            // 2. The database chooses the cars (rules, not AI)
            DataTable cars = ChatManager.RecommendCars(
                AnswerFor(1, chosen).Value, AnswerFor(2, chosen).Value, AnswerFor(3, chosen).Value,
                AnswerFor(4, chosen).Value, AnswerFor(5, chosen).Value);

            // 3. Save the chat and the answers
            int sessionId = ChatManager.CreateSession(notes);
            for (int i = 0; i < questions.Count; i++)
            {
                ChatManager.SaveAnswer(sessionId, questions[i].QuestionID, chosen[i].OptionID);
            }

            if (cars.Rows.Count == 0)
            {
                ChatManager.FinishSession(sessionId, "fallback", 0);
                ShowError("Sorry, none of our cars fits these answers. Please try different answers.");
                return;
            }

            // 4. The AI explains the chosen cars (or the standard explanation is used if the AI is off)
            ExplanationResult explanation = CarBudAssistant.Explain(trip, cars);

            // 5. Save the recommendations and remember them for booking
            List<RecommendationCard> cards = new List<RecommendationCard>();
            List<int> carIds = new List<int>();
            for (int i = 0; i < cars.Rows.Count; i++)
            {
                DataRow car = cars.Rows[i];
                RecommendationCard card = new RecommendationCard();
                card.CarID = Convert.ToInt32(car["CarID"]);
                card.RankLabel = i == 0 ? "Best match" : "Option " + (i + 1);
                card.Name = car["Make"] + " " + car["Model"];
                card.CarType = car["CarType"].ToString();
                card.Seats = Convert.ToInt32(car["Seats"]);
                card.BootLitres = Convert.ToInt32(car["BootLitres"]);
                card.FuelType = car["FuelType"].ToString();
                card.Comfort = Convert.ToInt32(car["ComfortRating"]);
                card.PricePerDay = Convert.ToInt32(car["PricePerDay"]);
                card.Score = Convert.ToInt32(car["Score"]);
                card.Reason = explanation.Reasons[i];
                cards.Add(card);
                carIds.Add(card.CarID);

                ChatManager.SaveRecommendation(sessionId, card.CarID, i + 1, card.Score, card.Reason);
            }
            ChatManager.FinishSession(sessionId, explanation.ModelUsed, explanation.ResponseMs);
            ChatManager.RememberChat(sessionId, carIds);

            // 6. Show the conversation and the results
            List<ChatLine> lines = new List<ChatLine>();
            for (int i = 0; i < questions.Count; i++)
            {
                lines.Add(new ChatLine { Question = questions[i].Text, Answer = chosen[i].Text });
            }
            rptTranscript.DataSource = lines;
            rptTranscript.DataBind();

            if (notes.Length > 0)
            {
                litNotes.Text = Server.HtmlEncode(notes);
                pnlNotesBubble.Visible = true;
            }

            litIntro.Text = Server.HtmlEncode(explanation.Intro);
            rptResults.DataSource = cards;
            rptResults.DataBind();

            string note;
            if (explanation.UsedAI)
            {
                note = string.Format(
                    "The cars were chosen by CarBud's fixed rules. The explanations were written by an AI model ({0}) in {1:0.0} seconds, and AI can make mistakes, so please check the car details before booking.",
                    explanation.ModelUsed, explanation.ResponseMs / 1000.0);
            }
            else if (explanation.CorrectedCount > 0)
            {
                note = "The cars were chosen by CarBud's fixed rules. The AI's explanations did not match the facts, so CarBud used its standard explanations instead.";
            }
            else
            {
                note = "The cars were chosen by CarBud's fixed rules. The AI assistant is not available right now, so CarBud used its standard explanations.";
            }

            if (explanation.UsedAI && explanation.CorrectedCount > 0)
            {
                note += explanation.CorrectedCount == 1
                    ? " One AI explanation did not match the facts, so CarBud replaced it with its standard explanation."
                    : string.Format(" {0} AI explanations did not match the facts, so CarBud replaced them with its standard explanations.", explanation.CorrectedCount);
            }
            litAiNote.Text = Server.HtmlEncode(note);

            pnlAsk.Visible = false;
            pnlResult.Visible = true;
        }

        // Turns "12,15,19,23,27" into the chosen answers. Returns null if anything is wrong.
        private List<ChatOption> ReadAnswers(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return null;
            }

            string[] parts = value.Split(',');
            if (parts.Length != questions.Count)
            {
                return null;
            }

            List<ChatOption> chosen = new List<ChatOption>();
            for (int i = 0; i < parts.Length; i++)
            {
                int optionId;
                if (!int.TryParse(parts[i], out optionId))
                {
                    return null;
                }
                ChatOption option = questions[i].Options.FirstOrDefault(o => o.OptionID == optionId);
                if (option == null)
                {
                    return null;   // not a real answer to this question
                }
                chosen.Add(option);
            }
            return chosen;
        }

        // The answer given to the question with this order number (1 to 5)
        private ChatOption AnswerFor(int order, List<ChatOption> chosen)
        {
            int index = questions.FindIndex(q => q.Order == order);
            return chosen[index];
        }

        private void ShowError(string text)
        {
            litError.Text = Server.HtmlEncode(text);
            pnlError.Visible = true;
            pnlAsk.Visible = false;
            pnlResult.Visible = false;
        }
    }
}
