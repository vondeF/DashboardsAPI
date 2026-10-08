using System.Reflection;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Unicode;

namespace DashboardsAPI
{
    public static class LuaScriptPreparator
    {
        public static string TransformToString(string scriptPath)
        {
            string luaScript = File.ReadAllText(scriptPath, Encoding.UTF8);
            var requestData = new
            {
                luaScript = luaScript,
                collectStdout = true
            };

            var options = new JsonSerializerOptions
            {
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
                WriteIndented = true
            };

            string json = JsonSerializer.Serialize(requestData, options);
            return json;
        }
    }
}
