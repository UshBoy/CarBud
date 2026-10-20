using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.Text;
using System.Web.Script.Serialization;

namespace CarBud_Proto1
{
    // What the customer answered, in words (for the AI) and numbers (for the rules)
    public class TripAnswers
    {
        public string Passengers { get; set; }
        public string Distance { get; set; }
        public string Luggage { get; set; }
        public string Budget { get; set; }
        public string Purpose { get; set; }
        public int DistanceValue { get; set; }
        public int BudgetValue { get; set; }       // highest price per day in kr (9999 = no limit)
        public string Notes { get; set; }
    }

    // The explanation shown to the customer
    public class ExplanationResult
    {
        public string Intro { get; set; }
        public List<string> Reasons { get; set; }   // one per car, same order as the cars
        public bool UsedAI { get; set; }
        public string ModelUsed { get; set; }       // the model name, or "fallback"
        public int ResponseMs { get; set; }         // how long the AI took
        public int CorrectedCount { get; set; }     // AI explanations replaced because they contradicted the facts

        public ExplanationResult()
        {
            Reasons = new List<string>();
        }
    }

    // CarBud's "voice". The database has ALREADY chosen the cars.
    // The AI only explains them, and it is only given facts about those cars,
    // so it cannot recommend a car that does not exist in our fleet.
    public static class CarBudAssistant
    {
        private const string SystemPrompt =
            "You are CarBud, the friendly assistant of CarBud Rentals. " +
            "You explain car recommendations to customers in plain, warm English. " +
            "Only use the facts you are given. Never invent cars, prices or features, " +
            "and never suggest a car that is not in the list.";

        public static ExplanationResult Explain(TripAnswers trip, DataTable cars)
        {
            string prompt = BuildPrompt(trip, cars);

            Stopwatch timer = Stopwatch.StartNew();
            string reply = OllamaHelper.Ask(SystemPrompt, prompt, true);
            timer.Stop();

            return BuildResult(reply, trip, cars, (int)timer.ElapsedMilliseconds);
        }

        // The question we send to the AI: the customer's answers plus the facts about the chosen cars
        public static string BuildPrompt(TripAnswers trip, DataTable cars)
        {
            StringBuilder p = new StringBuilder();
            p.AppendLine("The customer told us:");
            p.AppendLine("- People travelling: " + trip.Passengers);
            p.AppendLine("- Trip distance: " + trip.Distance);
            p.AppendLine("- Luggage: " + trip.Luggage);
            p.AppendLine("- Budget per day: " + trip.Budget);
            p.AppendLine("- Purpose: " + trip.Purpose);
            if (!string.IsNullOrWhiteSpace(trip.Notes))
            {
                p.AppendLine("- Extra note from the customer: " + trip.Notes);
            }
            p.AppendLine();
            p.AppendLine("Our rules chose these cars, best match first:");

            int number = 1;
            foreach (DataRow car in cars.Rows)
            {
                p.AppendFormat("{0}. {1} {2} ({3}): {4} seats, {5} litres of boot space, {6} kr per day, {7}, comfort {8} out of 5. ",
                    number, car["Make"], car["Model"], car["CarType"], car["Seats"], car["BootLitres"],
                    car["PricePerDay"], car["FuelType"], car["ComfortRating"]);
                p.AppendFormat("Match marks out of 100: seats {0}, luggage {1}, comfort {2}, purpose {3}. ",
                    car["SeatFit"], car["LuggageFit"], car["DistanceFit"], car["PurposeFit"]);
                p.Append(BudgetFact(car, trip));
                p.AppendLine();
                number++;
            }

            p.AppendLine();
            p.Append("Reply with JSON only, in this shape: {\"intro\": \"one friendly sentence\", \"why\": [");
            for (int i = 1; i <= cars.Rows.Count; i++)
            {
                p.Append(i > 1 ? ", " : "");
                p.Append("\"why car " + i + " suits this trip\"");
            }
            p.AppendLine("]}");
            p.AppendLine("Rules for each \"why\":");
            p.AppendLine("- Write two or three sentences that explain why this car suits this customer's trip.");
            p.AppendLine("- Connect the car's facts to what the customer told us: the number of people, the luggage, the distance, the purpose, the budget and their extra note.");
            p.AppendLine("- Do not repeat the car's name. Call it \"it\" or \"this car\".");
            p.AppendLine("- Be warm and natural, but only use the facts above. Do not invent features such as fuel economy, safety or extras.");
            p.AppendLine("- Get the budget right: use the budget fact exactly as given.");
            p.AppendLine("- If a match mark is below 60, say honestly what does not fit.");
            return p.ToString();
        }

        // Turns the AI's reply into an explanation. If the reply is missing or unusable,
        // each car gets the standard explanation instead.
        public static ExplanationResult BuildResult(string reply, TripAnswers trip, DataTable cars, int responseMs)
        {
            string aiIntro = null;
            List<string> aiReasons = new List<string>();

            if (!string.IsNullOrWhiteSpace(reply))
            {
                try
                {
                    Dictionary<string, object> parsed = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(reply);
                    Dictionary<string, object> data = new Dictionary<string, object>(parsed, StringComparer.OrdinalIgnoreCase);

                    object introObject;
                    if (data.TryGetValue("intro", out introObject))
                    {
                        aiIntro = Clean(introObject as string);
                    }

                    object whyObject;
                    if (data.TryGetValue("why", out whyObject) && whyObject is IEnumerable && !(whyObject is string))
                    {
                        foreach (object item in (IEnumerable)whyObject)
                        {
                            aiReasons.Add(Clean(item as string));
                        }
                    }
                }
                catch (Exception)
                {
                    // Not valid JSON: ignore the reply and use the standard explanations
                    aiIntro = null;
                    aiReasons.Clear();
                }
            }

            ExplanationResult result = new ExplanationResult();
            result.ResponseMs = responseMs;

            for (int i = 0; i < cars.Rows.Count; i++)
            {
                DataRow car = cars.Rows[i];
                string aiReason = i < aiReasons.Count ? RemoveCarName(aiReasons[i], car) : null;

                // Fact-check guard: an explanation that gets the budget wrong is not shown
                if (aiReason != null && ContradictsBudget(aiReason, ToInt(car["WithinBudget"]) == 1))
                {
                    aiReason = null;
                    result.CorrectedCount++;
                }

                if (aiReason != null)
                {
                    result.Reasons.Add(aiReason);
                    result.UsedAI = true;
                }
                else
                {
                    result.Reasons.Add(FallbackReason(car, trip));
                }
            }

            result.Intro = (result.UsedAI && aiIntro != null)
                ? aiIntro
                : "Here are the cars that suit your trip best.";
            result.ModelUsed = result.UsedAI ? OllamaHelper.ModelName : "fallback";
            return result;
        }

        // The standard explanation, built from the match marks. Used when the AI is not available.
        public static string FallbackReason(DataRow car, TripAnswers trip)
        {
            int seats = ToInt(car["Seats"]);
            int boot = ToInt(car["BootLitres"]);
            int price = ToInt(car["PricePerDay"]);
            int luggageFit = ToInt(car["LuggageFit"]);
            int comfortFit = ToInt(car["DistanceFit"]);
            bool withinBudget = ToInt(car["WithinBudget"]) == 1;

            string first = string.Format("It has {0} seats and {1} litres of boot space", seats, boot);
            if (luggageFit >= 100)
            {
                first += ", enough for your luggage";
            }
            else if (luggageFit > 0)
            {
                first += ", which is a little small for your luggage";
            }
            else
            {
                first += ", which is not enough for your luggage";
            }

            string second = withinBudget
                ? string.Format("At {0} kr a day it fits your budget", price)
                : string.Format("At {0} kr a day it is above your budget", price);

            if (comfortFit < 100)
            {
                second += ", but it is less comfortable for a trip this long";
            }
            else if (trip != null && trip.DistanceValue == 3)
            {
                second += ", and it is comfortable for long trips";
            }

            return first + ". " + second + ".";
        }

        // The budget fact for one car, in plain words, so the AI cannot misread it
        private static string BudgetFact(DataRow car, TripAnswers trip)
        {
            int price = ToInt(car["PricePerDay"]);
            if (trip == null || trip.BudgetValue <= 0 || trip.BudgetValue >= 9999)
            {
                return "Budget fact: the customer has no budget limit.";
            }
            return ToInt(car["WithinBudget"]) == 1
                ? string.Format("Budget fact: {0} kr per day is within the customer's budget of {1} kr per day.", price, trip.BudgetValue)
                : string.Format("Budget fact: {0} kr per day is over the customer's budget of {1} kr per day.", price, trip.BudgetValue);
        }

        // True if the AI says the opposite of the real budget fact
        public static bool ContradictsBudget(string reason, bool withinBudget)
        {
            string text = reason.ToLowerInvariant();
            string[] saysOver = { "above the limit", "above your budget", "above the budget", "above the customer's budget",
                                  "over budget", "over the budget", "over your budget", "over the customer's budget",
                                  "exceeds your budget", "exceeds the budget", "too expensive", "more than your budget", "out of your budget", "beyond your budget" };
            string[] saysWithin = { "within your budget", "within the budget", "within the customer's budget", "within the limit",
                                    "fits your budget", "fits the budget", "under your budget", "under budget", "affordable" };

            string[] wrongWords = withinBudget ? saysOver : saysWithin;
            foreach (string phrase in wrongWords)
            {
                if (text.Contains(phrase))
                {
                    return true;
                }
            }
            return false;
        }

        // Removes "Skoda Octavia Combi (Estate):" from the start, because the card already shows the name
        private static string RemoveCarName(string reason, DataRow car)
        {
            if (reason == null)
            {
                return null;
            }
            string name = car["Make"] + " " + car["Model"];
            if (reason.StartsWith(name, StringComparison.OrdinalIgnoreCase))
            {
                int colon = reason.IndexOf(':');
                if (colon >= 0 && colon <= name.Length + 20 && colon < reason.Length - 1)
                {
                    reason = reason.Substring(colon + 1).Trim();
                    if (reason.Length > 0)
                    {
                        reason = char.ToUpperInvariant(reason[0]) + reason.Substring(1);
                    }
                }
            }
            return reason.Length == 0 ? null : reason;
        }

        // Tidies a piece of AI text: no empty text, no line breaks, not too long
        private static string Clean(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
            {
                return null;
            }
            text = text.Replace("\r", " ").Replace("\n", " ").Trim();
            if (text.Length > 700)
            {
                text = text.Substring(0, 700).TrimEnd() + "...";
            }
            return text;
        }

        private static int ToInt(object value)
        {
            return value == null || value == DBNull.Value ? 0 : Convert.ToInt32(value);
        }
    }
}
