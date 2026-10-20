using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Net;
using System.Text;
using System.Web.Script.Serialization;

namespace CarBud_Proto1
{
    // The ONLY class that talks to the AI model.
    // Ollama runs on this computer and answers on http://localhost:11434.
    // To try another model, change "OllamaModel" in Web.config. No code changes are needed.
    public static class OllamaHelper
    {
        public static string ModelName
        {
            get { return Setting("OllamaModel", "llama3.2:3b"); }
        }

        private static string ChatUrl
        {
            get { return Setting("OllamaUrl", "http://localhost:11434").TrimEnd('/') + "/api/chat"; }
        }

        private static int TimeoutMs
        {
            get
            {
                int seconds;
                if (!int.TryParse(Setting("OllamaTimeoutSeconds", "90"), out seconds) || seconds <= 0)
                {
                    seconds = 90;
                }
                return seconds * 1000;
            }
        }

        // Sends the instructions and the question to the model and returns its reply.
        // Returns null if Ollama is not running, is too slow, or replies with something unexpected.
        // The caller then uses the standard (non-AI) explanation instead, so the website never breaks.
        public static string Ask(string systemPrompt, string userPrompt, bool replyAsJson)
        {
            try
            {
                JavaScriptSerializer json = new JavaScriptSerializer();

                List<Dictionary<string, object>> messages = new List<Dictionary<string, object>>();
                messages.Add(Message("system", systemPrompt));
                messages.Add(Message("user", userPrompt));

                Dictionary<string, object> options = new Dictionary<string, object>();
                options["temperature"] = 0.3;   // low = more focused, less random
                options["num_predict"] = 450;   // the longest reply allowed, in tokens (room for 2-3 sentences per car)

                Dictionary<string, object> body = new Dictionary<string, object>();
                body["model"] = ModelName;
                body["messages"] = messages;
                body["stream"] = false;         // wait for the whole reply
                body["keep_alive"] = "30m";     // keep the model in memory for 30 minutes, so the next chat is faster
                body["options"] = options;
                if (replyAsJson)
                {
                    body["format"] = "json";    // Ollama makes sure the reply is valid JSON
                }

                byte[] data = Encoding.UTF8.GetBytes(json.Serialize(body));

                HttpWebRequest request = (HttpWebRequest)WebRequest.Create(ChatUrl);
                request.Method = "POST";
                request.ContentType = "application/json";
                request.ContentLength = data.Length;
                request.Timeout = TimeoutMs;
                request.ReadWriteTimeout = TimeoutMs;
                request.Proxy = null;           // talk to this computer directly

                using (Stream requestStream = request.GetRequestStream())
                {
                    requestStream.Write(data, 0, data.Length);
                }

                using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
                using (StreamReader reader = new StreamReader(response.GetResponseStream(), Encoding.UTF8))
                {
                    Dictionary<string, object> reply = json.Deserialize<Dictionary<string, object>>(reader.ReadToEnd());

                    object messageObject;
                    if (reply != null && reply.TryGetValue("message", out messageObject))
                    {
                        Dictionary<string, object> message = messageObject as Dictionary<string, object>;
                        object content;
                        if (message != null && message.TryGetValue("content", out content))
                        {
                            return content as string;
                        }
                    }
                    return null;
                }
            }
            catch (Exception ex)
            {
                // Shown in Visual Studio's Output window while debugging
                System.Diagnostics.Debug.WriteLine("Ollama call failed: " + ex.Message);
                return null;
            }
        }

        private static Dictionary<string, object> Message(string role, string content)
        {
            Dictionary<string, object> message = new Dictionary<string, object>();
            message["role"] = role;
            message["content"] = content;
            return message;
        }

        private static string Setting(string key, string defaultValue)
        {
            string value = ConfigurationManager.AppSettings[key];
            return string.IsNullOrWhiteSpace(value) ? defaultValue : value.Trim();
        }
    }
}
