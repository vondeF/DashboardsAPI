using DashboardsAPI.Helpers;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DashboardsAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]/scripts")]
    public class AipController : ControllerBase
    {
        string _authUri;
        string _modelUri;
        ModelService _modelService;

        public AipController()
        {
            this._authUri = @"https://ia-scada-w.cdu.so:9443/auth/nego/token";
            this._modelUri = @"https://ia-scada-w.cdu.so/api/public/object-models/v2.3/2000001c-0000-0000-c000-0000006d746c/versions/actual";
            this._modelService = new ModelService(this._authUri, this._modelUri);
        }

        [HttpGet("{scriptName}")]
        public async Task<ActionResult<ScriptResult>> ExecuteScript(string scriptName)
        {
            string appPath = AppContext.BaseDirectory;
            string scriptPath = "";
            try
            {
                scriptPath = Path.Combine(appPath, "LuaScripts", "AIP", $"{scriptName}.lua");
            }
            catch { throw new Exception("Wrong name of script"); }
            
            if (!System.IO.File.Exists(scriptPath))
                throw new FileNotFoundException(scriptPath);
            
            return await ExecuteScriptAsync(scriptPath);
        }


        private async Task<ActionResult<ScriptResult>> ExecuteScriptAsync(string scriptPath)
        {
            try
            {
                var script = LuaScriptPreparator.TransformToString(scriptPath);
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(300));
                var result = await _modelService.RunScriptAsync(script, scriptPath).WaitAsync(cts.Token);

                return Ok(new ScriptResult
                {
                    Success = true,
                    ScriptName = scriptPath,
                    Data = result,
                    ExecutionTime = DateTime.UtcNow
                });
            }
            catch (OperationCanceledException)
            {
                throw new TimeoutException($"Script execution exceeded timeout");
            }
        }
    }

    public class ScriptResult
    {
        public bool Success { get; set; }
        public string ScriptName { get; set; }
        public object Data { get; set; }
        public DateTime ExecutionTime { get; set; }
    }
}
