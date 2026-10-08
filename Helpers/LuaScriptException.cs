namespace DashboardsAPI.Helpers
{
    public class LuaScriptException : Exception
    {
        public string ScriptName { get; }
        public LuaScriptException(string message, string scriptName) : base(message)
        {
            ScriptName = scriptName;
        }
    }
}
