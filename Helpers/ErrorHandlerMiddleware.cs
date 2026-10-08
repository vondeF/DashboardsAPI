using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Net;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace DashboardsAPI.Helpers
{
    public class ErrorHandlerMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<ErrorHandlerMiddleware> _logger;

        public ErrorHandlerMiddleware(RequestDelegate next, ILogger<ErrorHandlerMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            try
            {
                await _next(context);
            }
            catch (Exception ex)
            {
                await HandleExceptionAsync(context, ex);
            }
        }

        private async Task HandleExceptionAsync(HttpContext context, Exception ex)
        {
            context.Response.ContentType = "application/json";

            var response = new ErrorResponse
            {
                RequestId = context.TraceIdentifier,
                Timestamp = DateTime.UtcNow,
                Message = ex.Message
            };

            switch (ex)
            {
                case LuaScriptException luaEx:
                    context.Response.StatusCode = (int)HttpStatusCode.BadRequest;
                    response.Code = "LUA_ERROR";
                    response.Details = luaEx.ScriptName;
                    _logger.LogError("Lua script error in {ScriptName}: {Message}", luaEx.ScriptName, luaEx.Message);
                    break;

                case TimeoutException:
                    context.Response.StatusCode = (int)HttpStatusCode.RequestTimeout;
                    response.Code = "TIMEOUT";
                    _logger.LogError("Request timed out: {Path}", context.Request.Path);
                    break;

                case HttpRequestException:
                    context.Response.StatusCode = (int)HttpStatusCode.ServiceUnavailable;
                    response.Code = "SERVICE_UNAVAILABLE";
                    _logger.LogError("External service unavailable: {Message}", ex.Message);
                    break;

                case UnauthorizedAccessException:
                    context.Response.StatusCode = (int)HttpStatusCode.Unauthorized;
                    response.Code = "UNAUTHORIZED";
                    _logger.LogError("Unauthorized access attempt to {Path}", context.Request.Path);
                    break;

                case TaskCanceledException:
                case OperationCanceledException:
                    context.Response.StatusCode = (int)HttpStatusCode.RequestTimeout;
                    response.Code = "CANCELLED";
                    _logger.LogError("Operation was cancelled: {Path}", context.Request.Path);
                    break;

                case JsonException:
                    context.Response.StatusCode = (int)HttpStatusCode.BadRequest;
                    response.Code = "INVALID_JSON";
                    _logger.LogError("Invalid json response", context.Request.Path);
                    break;

                default:
                    context.Response.StatusCode = 500;
                    response.Code = "UNKNOWN_ERROR";
                    _logger.LogError("Unhandled exception: {Message}", ex.Message);
                    break;
            }
            await context.Response.WriteAsync(JsonSerializer.Serialize(response));
        }
    }

    public class ErrorResponse
    {
        public string RequestId { get; set; }
        public DateTime Timestamp { get; set; }
        public string Code { get; set; }
        public string Message { get; set; }
        public string Details { get; set; }
    }
}
